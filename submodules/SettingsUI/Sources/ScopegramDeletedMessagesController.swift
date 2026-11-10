import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import UndoUI
import AlertUI
import LocalizedPeerData

private final class ScopegramDeletedMessagesArguments {
    let context: AccountContext
    let openMessageActions: (Message) -> Void
    
    init(context: AccountContext, openMessageActions: @escaping (Message) -> Void) {
        self.context = context
        self.openMessageActions = openMessageActions
    }
}

private enum ScopegramDeletedMessageEntry: ItemListNodeEntry {
    case infoHeader
    case messageItem(index: Int, message: Message, title: String, content: String)
    case emptyState
    
    var section: ItemListSectionId {
        return 0
    }
    
    var stableId: Int32 {
        switch self {
        case .infoHeader:
            return 0
        case let .messageItem(index, _, _, _):
            return 1 + Int32(index)
        case .emptyState:
            return 999999
        }
    }
    
    static func <(lhs: ScopegramDeletedMessageEntry, rhs: ScopegramDeletedMessageEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    static func ==(lhs: ScopegramDeletedMessageEntry, rhs: ScopegramDeletedMessageEntry) -> Bool {
        return lhs.stableId == rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ScopegramDeletedMessagesArguments
        switch self {
        case .infoHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "СОХРАНЁННЫЕ УДАЛЁННЫЕ СООБЩЕНИЯ", sectionId: self.section)
        case let .messageItem(_, message, title, content):
            return ItemListDisclosureItem(
                presentationData: presentationData,
                title: title,
                label: content,
                labelStyle: .multilineDetailText,
                additionalDetailLabel: "🗑",
                sectionId: self.section,
                style: .blocks,
                disclosureStyle: .arrow,
                action: {
                    arguments.openMessageActions(message)
                }
            )
        case .emptyState:
            return ItemListTextItem(
                presentationData: presentationData,
                text: .plain("В этом диалоге пока нет удалённых сообщений.\n\nКогда собеседник удалит сообщение, Anti-Delete автоматически сохранит его здесь."),
                sectionId: self.section
            )
        }
    }
}

private func describeMessageContent(_ message: Message) -> String {
    var parts: [String] = []
    for media in message.media {
        if media is TelegramMediaImage {
            parts.append("📷 Фото")
        } else if let file = media as? TelegramMediaFile {
            if file.isVoice {
                let duration = file.duration.flatMap { d -> String in
                    let total = Int(d)
                    return "\(total / 60):\(String(format: "%02d", total % 60))"
                } ?? ""
                parts.append("🎤 Голосовое (\(duration))")
            } else if file.isInstantVideo {
                parts.append("📹 Кружочек")
            } else if file.isVideo {
                parts.append("📹 Видео")
            } else if file.isSticker {
                var emoji = ""
                for attr in file.attributes {
                    if case let .Sticker(displayText, _, _) = attr {
                        emoji = displayText
                        break
                    }
                }
                parts.append("🎭 Стикер \(emoji)")
            } else {
                let name = file.fileName ?? "Файл"
                parts.append("📎 \(name)")
            }
        } else if media is TelegramMediaContact {
            parts.append("👤 Контакт")
        } else if media is TelegramMediaMap {
            parts.append("📍 Геолокация")
        } else if media is TelegramMediaPoll {
            parts.append("📊 Опрос")
        } else if media is TelegramMediaAction {
            parts.append("⚡️ Действие")
        }
    }
    
    let text = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
    if !text.isEmpty {
        if !parts.isEmpty {
            return "\(parts.joined(separator: ", "))\n\(text)"
        } else {
            return text
        }
    } else if !parts.isEmpty {
        return parts.joined(separator: ", ")
    } else {
        return "Без текста"
    }
}

private func formatMessageDate(_ timestamp: Int32) -> String {
    let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
    let formatter = DateFormatter()
    formatter.dateFormat = "d MMM, HH:mm:ss"
    return formatter.string(from: date)
}

public func scopegramDeletedMessagesController(context: AccountContext, peerId: PeerId) -> ViewController {
    var presentControllerImpl: ((ViewController) -> Void)?
    var navigateToMessageImpl: ((Message) -> Void)?
    
    var stateValue = 0
    let statePromise = ValuePromise<Int>(0, ignoreRepeated: false)
    
    let arguments = ScopegramDeletedMessagesArguments(context: context, openMessageActions: { message in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let actionSheet = ActionSheetController(presentationData: presentationData)
        
        let authorName = (message.author?.id == context.account.peerId) ? "Вы" : (message.author.flatMap({ EnginePeer($0).compactDisplayTitle }) ?? "Собеседник")
        let dateText = formatMessageDate(message.timestamp)
        
        var sheetItems: [ActionSheetItem] = []
        sheetItems.append(ActionSheetTextItem(title: "Удалённое сообщение\nОт: \(authorName) (\(dateText))"))
        
        sheetItems.append(ActionSheetButtonItem(title: "Перейти к сообщению в чате", color: .accent, action: { [weak actionSheet] in
            actionSheet?.dismissAnimated()
            navigateToMessageImpl?(message)
        }))
        
        let text = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            sheetItems.append(ActionSheetButtonItem(title: "Скопировать текст", color: .accent, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                UIPasteboard.general.string = text
                presentControllerImpl?(UndoOverlayController(presentationData: presentationData, content: .linkCopied(title: nil, text: "Текст скопирован"), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }))
            }))
        }
        
        sheetItems.append(ActionSheetButtonItem(title: "Удалить из этого списка", color: .destructive, action: { [weak actionSheet] in
            actionSheet?.dismissAnimated()
            ScopegramAntiDeleteRegistry.shared.remove(messageId: message.id)
            stateValue += 1
            statePromise.set(stateValue)
        }))
        
        actionSheet.setItemGroups([
            ActionSheetItemGroup(items: sheetItems),
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                })
            ])
        ])
        
        presentControllerImpl?(actionSheet)
    })
    
    let signal: Signal<(ItemListControllerState, (ItemListNodeState, ScopegramDeletedMessagesArguments)), NoError> = combineLatest(
        context.sharedContext.presentationData,
        statePromise.get(),
        context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
    )
    |> deliverOnMainQueue
    |> mapToSignal { presentationData, _, peer -> Signal<(ItemListControllerState, (ItemListNodeState, ScopegramDeletedMessagesArguments)), NoError> in
        let candidateIds = ScopegramAntiDeleteRegistry.shared.deletedMessageIds(for: peerId)
        
        let messagesSignal: Signal<[Message], NoError>
        if candidateIds.isEmpty {
            messagesSignal = .single([])
        } else {
            messagesSignal = context.account.postbox.messagesAtIds(candidateIds)
        }
        
        return messagesSignal
        |> deliverOnMainQueue
        |> map { messages -> (ItemListControllerState, (ItemListNodeState, ScopegramDeletedMessagesArguments)) in
            let sortedMessages = messages.sorted(by: { $0.timestamp > $1.timestamp })
            
            var entries: [ScopegramDeletedMessageEntry] = []
            if sortedMessages.isEmpty {
                entries.append(.emptyState)
            } else {
                entries.append(.infoHeader)
                for (idx, msg) in sortedMessages.enumerated() {
                    let authorName = (msg.author?.id == context.account.peerId) ? "Вы" : (msg.author.flatMap({ EnginePeer($0).compactDisplayTitle }) ?? "Собеседник")
                    let dateStr = formatMessageDate(msg.timestamp)
                    let contentDesc = describeMessageContent(msg)
                    entries.append(.messageItem(index: idx, message: msg, title: "\(authorName) · \(dateStr)", content: contentDesc))
                }
            }
            
            let clearAction: () -> Void = {
                let alert = textAlertController(
                    context: context,
                    title: "Очистить список?",
                    text: "Все записи об удалённых сообщениях для этого диалога будут удалены из списка истории.",
                    actions: [
                        TextAlertAction(type: .destructiveAction, title: "Очистить", action: {
                            ScopegramAntiDeleteRegistry.shared.clear(for: peerId)
                            stateValue += 1
                            statePromise.set(stateValue)
                        }),
                        TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_Cancel, action: {})
                    ]
                )
                presentControllerImpl?(alert)
            }
            
            let rightButton: ItemListNavigationButton?
            if !sortedMessages.isEmpty {
                rightButton = ItemListNavigationButton(content: .text("Очистить"), style: .bold, enabled: true, action: clearAction)
            } else {
                rightButton = nil
            }
            
            let peerTitle = peer?.compactDisplayTitle ?? "Диалог"
            let controllerState = ItemListControllerState(
                presentationData: ItemListPresentationData(presentationData),
                title: .text("Удалённые (\(peerTitle))"),
                leftNavigationButton: nil,
                rightNavigationButton: rightButton,
                backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
            )
            let listState = ItemListNodeState(
                presentationData: ItemListPresentationData(presentationData),
                entries: entries,
                style: .blocks,
                animateChanges: true
            )
            return (controllerState, (listState, arguments))
        }
    }
    
    let controller = ItemListController(context: context, state: signal)
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .current)
    }
    navigateToMessageImpl = { [weak controller] message in
        guard let controller = controller, let navigationController = controller.navigationController as? NavigationController else {
            return
        }
        let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
        |> deliverOnMainQueue).startStandalone(next: { peer in
            guard let peer = peer else {
                return
            }
            context.sharedContext.navigateToChatController(NavigateToChatControllerParams(
                navigationController: navigationController,
                context: context,
                chatLocation: .peer(peer),
                subject: .message(id: .id(message.id), highlight: ChatControllerSubject.MessageHighlight(quote: nil), timecode: nil, setupReply: false),
                keepStack: .always,
                useExisting: true
            ))
        })
    }
    return controller
}
