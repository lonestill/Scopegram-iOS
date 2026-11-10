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
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import AppBundle
import UndoUI

private final class ScopegramModIconHeaderItem: ListViewItem, ItemListItem {
    let context: AccountContext
    let theme: PresentationTheme
    let sectionId: ItemListSectionId
    
    init(context: AccountContext, theme: PresentationTheme, sectionId: ItemListSectionId) {
        self.context = context
        self.theme = theme
        self.sectionId = sectionId
    }
    
    var selectable: Bool { return false }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, neighbors: ListViewItemNeighbors, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ScopegramModIconHeaderItemNode(context: self.context)
            let (layout, apply) = node.asyncLayout()(self, params, itemListNeighbors(item: self, topFacet: neighbors.previous?.base(ItemListNeighborFacet.self), bottomFacet: neighbors.next?.base(ItemListNeighborFacet.self)))
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in apply() })
                })
            }
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, neighbors: ListViewItemNeighbors, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            guard let nodeValue = node() as? ScopegramModIconHeaderItemNode else {
                assertionFailure()
                return
            }
            
            let makeLayout = nodeValue.asyncLayout()
            
            async {
                let (layout, apply) = makeLayout(self, params, itemListNeighbors(item: self, topFacet: neighbors.previous?.base(ItemListNeighborFacet.self), bottomFacet: neighbors.next?.base(ItemListNeighborFacet.self)))
                Queue.mainQueue().async {
                    completion(layout, { _ in
                        apply()
                    })
                }
            }
        }
    }
}

private final class ScopegramModIconHeaderItemNode: ListViewItemNode {
    private var animationNode: AnimatedStickerNode
    private var imageNode: ASImageNode
    private var item: ScopegramModIconHeaderItem?
    private var isAnimationInitialized = false
    private let context: AccountContext

    init(context: AccountContext) {
        self.context = context
        self.animationNode = DefaultAnimatedStickerNodeImpl(lottieSettings: context.lottieRenderingSettings)
        self.imageNode = ASImageNode()
        self.imageNode.contentMode = .scaleAspectFit
        self.imageNode.displaysAsynchronously = false
        
        super.init(layerBacked: false)
        
        self.addSubnode(self.imageNode)
        self.addSubnode(self.animationNode)
    }
    
    func asyncLayout() -> (_ item: ScopegramModIconHeaderItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        return { [weak self] item, params, neighbors in
            let topInset: CGFloat = 110.0
            let contentSize = CGSize(width: params.width, height: topInset)
            let insets = itemListNeighborsGroupedInsets(neighbors, params)
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            
            return (layout, { [weak self] in
                guard let strongSelf = self else { return }
                strongSelf.item = item
                let iconSize = CGSize(width: 84.0, height: 84.0)
                let origin = CGPoint(x: params.leftInset + floor((layout.size.width - params.leftInset - params.rightInset - iconSize.width) / 2.0), y: 14.0)
                let iconFrame = CGRect(origin: origin, size: iconSize)
                
                strongSelf.imageNode.frame = iconFrame
                strongSelf.animationNode.frame = iconFrame
                
                if strongSelf.imageNode.image == nil {
                    strongSelf.imageNode.image = UIImage(bundleImageName: "Settings/ScopegramModIconHeader")
                }
                
                if !strongSelf.isAnimationInitialized {
                    strongSelf.isAnimationInitialized = true
                    strongSelf.animationNode.setup(source: AnimatedStickerNodeLocalFileSource(name: "scopegram_modicon"), width: 168, height: 168, playbackMode: .loop, mode: .direct(cachePathPrefix: nil))
                    strongSelf.animationNode.visibility = true
                }
                strongSelf.animationNode.updateLayout(size: iconSize)
            })
        }
    }
}

// MARK: - Root Scopegram Settings (Categories Hub)

private final class ScopegramRootArguments {
    let context: AccountContext
    let openCategory: (ViewController) -> Void
    let openUrl: (String) -> Void
    let openChannel: () -> Void
    let checkUpdates: () -> Void
    
    init(context: AccountContext, openCategory: @escaping (ViewController) -> Void, openUrl: @escaping (String) -> Void, openChannel: @escaping () -> Void, checkUpdates: @escaping () -> Void) {
        self.context = context
        self.openCategory = openCategory
        self.openUrl = openUrl
        self.openChannel = openChannel
        self.checkUpdates = checkUpdates
    }
}

private enum ScopegramRootSection: Int32 {
    case categories
    case clientInfo
}

private enum ScopegramRootEntry: ItemListNodeEntry {
    case modIconHeader(PresentationTheme)
    case categoriesHeader
    case ghostCategory
    case chatCategory
    case mediaCategory
    case securityCategory
    case cleanUICategory
    case categoriesFooter
    
    case clientInfoHeader
    case engineInfo
    case officialChannel
    case gitHubRepo
    case checkUpdates
    case clientInfoFooter
    
    var section: ItemListSectionId {
        switch self {
        case .modIconHeader, .categoriesHeader, .ghostCategory, .chatCategory, .mediaCategory, .securityCategory, .cleanUICategory, .categoriesFooter:
            return ScopegramRootSection.categories.rawValue
        case .clientInfoHeader, .engineInfo, .officialChannel, .gitHubRepo, .checkUpdates, .clientInfoFooter:
            return ScopegramRootSection.clientInfo.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
        case .modIconHeader: return 0
        case .categoriesHeader: return 1
        case .ghostCategory: return 2
        case .chatCategory: return 3
        case .mediaCategory: return 4
        case .securityCategory: return 5
        case .cleanUICategory: return 6
        case .categoriesFooter: return 7
        case .clientInfoHeader: return 8
        case .engineInfo: return 9
        case .officialChannel: return 10
        case .gitHubRepo: return 11
        case .checkUpdates: return 12
        case .clientInfoFooter: return 13
        }
    }
    
    static func <(lhs: ScopegramRootEntry, rhs: ScopegramRootEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ScopegramRootArguments
        switch self {
        case let .modIconHeader(theme):
            return ScopegramModIconHeaderItem(context: arguments.context, theme: theme, sectionId: self.section)
        case .categoriesHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "CATEGORIES", sectionId: self.section)
        case .ghostCategory:
            return ItemListDisclosureItem(presentationData: presentationData, title: "Privacy & Stealth", label: "Ghost Mode, Stealth Stories, Phones", sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                arguments.openCategory(scopegramGhostSettingsController(context: arguments.context))
            })
        case .chatCategory:
            return ItemListDisclosureItem(presentationData: presentationData, title: "Chats & Messages", label: "Anti-Delete, Seconds, Bypass, Commands", sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                arguments.openCategory(scopegramChatSettingsController(context: arguments.context))
            })
        case .mediaCategory:
            return ItemListDisclosureItem(presentationData: presentationData, title: "Media & Files", label: "Disappearing Media, Send as Voice/Round", sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                arguments.openCategory(scopegramMediaSettingsController(context: arguments.context))
            })
        case .securityCategory:
            return ItemListDisclosureItem(presentationData: presentationData, title: "Security & Info", label: "Call Confirm, Peer ID, DC & Age", sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                arguments.openCategory(scopegramSecuritySettingsController(context: arguments.context))
            })
        case .cleanUICategory:
            return ItemListDisclosureItem(presentationData: presentationData, title: "Interface & AdBlock", label: "Channel AdBlock, Diagnostics", sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                arguments.openCategory(scopegramCleanUISettingsController(context: arguments.context))
            })
        case .categoriesFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Select a category above to configure Scopegram client features."), sectionId: self.section)
            
        case .clientInfoHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "CLIENT INFO", sectionId: self.section)
        case .engineInfo:
            return ItemListDisclosureItem(presentationData: presentationData, title: "Engine", label: "Scopegram Native v1.0", sectionId: self.section, style: .blocks, disclosureStyle: .none, action: nil)
        case .officialChannel:
            return ItemListDisclosureItem(presentationData: presentationData, title: "Official Channel", label: "@scopegramapp", sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                arguments.openChannel()
            })
        case .gitHubRepo:
            return ItemListDisclosureItem(presentationData: presentationData, title: "GitHub Repository", label: "lonestill/Scopegram-iOS", sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                arguments.openUrl("https://github.com/lonestill/Scopegram-iOS")
            })
        case .checkUpdates:
            return ItemListDisclosureItem(presentationData: presentationData, title: "Check for Updates", label: "", sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                arguments.checkUpdates()
            })
        case .clientInfoFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Direct GitHub Releases updates. Zero external trackers."), sectionId: self.section)
        }
    }
}

public func scopegramSettingsController(context: AccountContext) -> ViewController {
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController) -> Void)?
    var getNavigationControllerImpl: (() -> NavigationController?)?
    
    let arguments = ScopegramRootArguments(
        context: context,
        openCategory: { target in
            pushControllerImpl?(target)
        },
        openUrl: { url in
            context.sharedContext.applicationBindings.openUrl(url)
        },
        openChannel: {
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let hud = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: nil))
            presentControllerImpl?(hud)
            
            let _ = (context.engine.peers.resolvePeerByName(name: "scopegramapp", referrer: nil, ageLimit: 10)
            |> mapToSignal { result -> Signal<EnginePeer?, NoError> in
                guard case let .result(peer) = result else {
                    return .single(nil)
                }
                return .single(peer)
            }
            |> deliverOnMainQueue).start(next: { [weak hud] peer in
                hud?.dismiss()
                if let peer = peer, let navigationController = getNavigationControllerImpl?() {
                    context.sharedContext.navigateToChatController(NavigateToChatControllerParams(
                        navigationController: navigationController,
                        context: context,
                        chatLocation: .peer(peer)
                    ))
                } else {
                    context.sharedContext.applicationBindings.openUrl("https://t.me/scopegramapp")
                }
            })
        },
        checkUpdates: {
            if let navigationController = getNavigationControllerImpl?() {
                ScopegramUpdateChecker.shared.checkManual(from: navigationController)
            }
        }
    )
    
    let signal = context.sharedContext.presentationData
    |> deliverOnMainQueue
    |> map { presentationData -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var entries: [ScopegramRootEntry] = []
        entries.append(.modIconHeader(presentationData.theme))
        entries.append(.categoriesHeader)
        entries.append(.ghostCategory)
        entries.append(.chatCategory)
        entries.append(.mediaCategory)
        entries.append(.securityCategory)
        entries.append(.cleanUICategory)
        entries.append(.categoriesFooter)
        
        entries.append(.clientInfoHeader)
        entries.append(.engineInfo)
        entries.append(.officialChannel)
        entries.append(.gitHubRepo)
        entries.append(.checkUpdates)
        entries.append(.clientInfoFooter)
        
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("Scopegram"),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: entries,
            style: .blocks,
            animateChanges: false
        )
        
        return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(context: context, state: signal)
    pushControllerImpl = { [weak controller] target in
        (controller?.navigationController as? NavigationController)?.pushViewController(target)
    }
    presentControllerImpl = { [weak controller] target in
        controller?.present(target, in: .window(.root))
    }
    getNavigationControllerImpl = { [weak controller] in
        return controller?.navigationController as? NavigationController
    }
    return controller
}

// MARK: - Category 1: Ghost & Privacy

private final class ScopegramGhostArguments {
    let toggleSetting: (String, Bool) -> Void
    init(toggleSetting: @escaping (String, Bool) -> Void) {
        self.toggleSetting = toggleSetting
    }
}

private enum ScopegramGhostSection: Int32 {
    case master
    case granular
}

private enum ScopegramGhostEntry: ItemListNodeEntry {
    case masterHeader
    case ghostMode(Bool)
    case masterFooter
    
    case granularHeader
    case dontRead(Bool)
    case hideTyping(Bool)
    case stealthStories(Bool)
    case hidePhones(Bool)
    case granularFooter
    
    var section: ItemListSectionId {
        switch self {
        case .masterHeader, .ghostMode, .masterFooter:
            return ScopegramGhostSection.master.rawValue
        case .granularHeader, .dontRead, .hideTyping, .stealthStories, .hidePhones, .granularFooter:
            return ScopegramGhostSection.granular.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
        case .masterHeader: return 0
        case .ghostMode: return 1
        case .masterFooter: return 2
        case .granularHeader: return 3
        case .dontRead: return 4
        case .hideTyping: return 5
        case .stealthStories: return 6
        case .hidePhones: return 7
        case .granularFooter: return 8
        }
    }
    
    static func <(lhs: ScopegramGhostEntry, rhs: ScopegramGhostEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ScopegramGhostArguments
        switch self {
        case .masterHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "MASTER GHOST SWITCH", sectionId: self.section)
        case let .ghostMode(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Ghost Mode (Master)", value: value, sectionId: self.section, style: .blocks, updated: { val in
                arguments.toggleSetting("scopegram.ghostMode", val)
                UserDefaults.standard.set(val, forKey: "chargedGram.ghostMode")
                UserDefaults.standard.set(val, forKey: "mod.keepChatsUnread")
            })
        case .masterFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain("When enabled, acts as a master override for all stealth features below."), sectionId: self.section)
            
        case .granularHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "GRANULAR PRIVACY CONTROLS", sectionId: self.section)
        case let .dontRead(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Don't Send Read Receipts", value: value, sectionId: self.section, style: .blocks, updated: { val in
                arguments.toggleSetting("scopegram.dontReadMessages", val)
            })
        case let .hideTyping(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Don't Send Typing / Voice Status", value: value, sectionId: self.section, style: .blocks, updated: { val in
                arguments.toggleSetting("scopegram.hideTyping", val)
            })
        case let .stealthStories(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Stealth Stories Viewing", value: value, sectionId: self.section, style: .blocks, updated: { val in
                arguments.toggleSetting("scopegram.stealthStories", val)
            })
        case let .hidePhones(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Hide Phone Numbers in Profiles", value: value, sectionId: self.section, style: .blocks, updated: { val in
                arguments.toggleSetting("scopegram.hidePhoneNumbers", val)
                UserDefaults.standard.set(val, forKey: "chargedGram.hidePhoneNumbers")
            })
        case .granularFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Stealth Stories lets you view any contact's stories without your name ever appearing in their viewer list. Hide Phone Numbers masks numbers across all screens."), sectionId: self.section)
        }
    }
}

public func scopegramGhostSettingsController(context: AccountContext) -> ViewController {
    let statePromise = ValuePromise<Int>(0, ignoreRepeated: false)
    var stateValue = 0
    let arguments = ScopegramGhostArguments(toggleSetting: { key, val in
        UserDefaults.standard.set(val, forKey: key)
        stateValue += 1
        statePromise.set(stateValue)
    })
    
    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get())
    |> deliverOnMainQueue
    |> map { presentationData, _ -> (ItemListControllerState, (ItemListNodeState, ScopegramGhostArguments)) in
        let ud = UserDefaults.standard
        let ghostMode = ud.bool(forKey: "scopegram.ghostMode") || ud.bool(forKey: "chargedGram.ghostMode") || ud.bool(forKey: "mod.keepChatsUnread")
        let dontRead = ghostMode || ud.bool(forKey: "scopegram.dontReadMessages")
        let hideTyping = ghostMode || ud.bool(forKey: "scopegram.hideTyping")
        let stealthStories = ghostMode || ud.bool(forKey: "scopegram.stealthStories")
        let hidePhones = ud.bool(forKey: "scopegram.hidePhoneNumbers") || ud.bool(forKey: "chargedGram.hidePhoneNumbers")
        
        var entries: [ScopegramGhostEntry] = []
        entries.append(.masterHeader)
        entries.append(.ghostMode(ghostMode))
        entries.append(.masterFooter)
        entries.append(.granularHeader)
        entries.append(.dontRead(dontRead))
        entries.append(.hideTyping(hideTyping))
        entries.append(.stealthStories(stealthStories))
        entries.append(.hidePhones(hidePhones))
        entries.append(.granularFooter)
        
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("Privacy & Stealth"),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: entries,
            style: .blocks,
            animateChanges: false
        )
        return (controllerState, (listState, arguments))
    }
    return ItemListController(context: context, state: signal)
}

// MARK: - Category 2: Chats & Messaging

private struct ScopegramCommandInfo {
    let command: String
    let desc: String
    let usage: String
}

private let scopegramCommandList: [ScopegramCommandInfo] = [
    ScopegramCommandInfo(command: "/fake code [код]", desc: "Официальный код авторизации Telegram", usage: "/fake code"),
    ScopegramCommandInfo(command: "/fake gift [3|6|12]", desc: "Подарок Telegram Premium (3, 6, 12 мес)", usage: "/fake gift 12"),
    ScopegramCommandInfo(command: "/fake promo [код]", desc: "Подарочный промокод на подписку", usage: "/fake promo"),
    ScopegramCommandInfo(command: "/fake stars [кол-во]", desc: "Перевод Telegram Stars (звёзды)", usage: "/fake stars 5000"),
    ScopegramCommandInfo(command: "/fake ban [причина]", desc: "Сервисный алерт о блокировке за нарушение ToS", usage: "/fake ban"),
    ScopegramCommandInfo(command: "/fake warn [текст]", desc: "Предупреждение службы безопасности", usage: "/fake warn"),
    ScopegramCommandInfo(command: "/fake verify [имя]", desc: "Одобрение верификации профиля (синяя галочка)", usage: "/fake verify"),
    ScopegramCommandInfo(command: "/fake login [инфо]", desc: "Алерт о входе с неизвестного устройства", usage: "/fake login"),
    ScopegramCommandInfo(command: "/fake call [missed|5m|video]", desc: "Системная плашка звонка Telegram", usage: "/fake call missed"),
    ScopegramCommandInfo(command: "/fake screen", desc: "Системный алерт о скриншоте диалога", usage: "/fake screen"),
    ScopegramCommandInfo(command: "/fake pay [сумма]", desc: "Квитанция об оплате счёта", usage: "/fake pay 100"),
    ScopegramCommandInfo(command: "/fake refund [сумма]", desc: "Квитанция возврата средств", usage: "/fake refund 100"),
    ScopegramCommandInfo(command: "/fake help", desc: "Полный список возможностей генератора", usage: "/fake help"),
    ScopegramCommandInfo(command: "/fake here <команда>", desc: "Модификатор: отправить в текущий чат вместо 777000", usage: "/fake here code"),
    ScopegramCommandInfo(command: "/fake noswitch <команда>", desc: "Модификатор: отправить в 777000 без перехода", usage: "/fake noswitch gift 12")
]

private final class ScopegramChatArguments {
    let toggleSetting: (String, Bool) -> Void
    let toggleCommandsExpanded: () -> Void
    let copyCommand: (String) -> Void
    
    init(toggleSetting: @escaping (String, Bool) -> Void, toggleCommandsExpanded: @escaping () -> Void, copyCommand: @escaping (String) -> Void) {
        self.toggleSetting = toggleSetting
        self.toggleCommandsExpanded = toggleCommandsExpanded
        self.copyCommand = copyCommand
    }
}

private enum ScopegramChatSection: Int32 {
    case main
    case commands
}

private enum ScopegramChatEntry: ItemListNodeEntry {
    case header
    case antiDelete(Bool)
    case allowCopy(Bool)
    case secondsInTimestamp(Bool)
    case reactions(Bool)
    case clientCommands(Bool)
    case footer
    
    case commandsHeader
    case commandsToggle(isExpanded: Bool, count: Int)
    case commandItem(index: Int, command: String, description: String, usage: String)
    case commandsFooter(isExpanded: Bool)
    
    var section: ItemListSectionId {
        switch self {
        case .header, .antiDelete, .allowCopy, .secondsInTimestamp, .reactions, .clientCommands, .footer:
            return ScopegramChatSection.main.rawValue
        case .commandsHeader, .commandsToggle, .commandItem, .commandsFooter:
            return ScopegramChatSection.commands.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
        case .header: return 0
        case .antiDelete: return 1
        case .allowCopy: return 2
        case .secondsInTimestamp: return 3
        case .reactions: return 4
        case .clientCommands: return 5
        case .footer: return 6
        case .commandsHeader: return 100
        case .commandsToggle: return 101
        case let .commandItem(index, _, _, _): return 102 + Int32(index)
        case .commandsFooter: return 300
        }
    }
    
    static func <(lhs: ScopegramChatEntry, rhs: ScopegramChatEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ScopegramChatArguments
        switch self {
        case .header:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "MESSAGE PRESERVATION & BYPASSES", sectionId: self.section)
        case let .antiDelete(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Anti-Delete Messages", value: value, sectionId: self.section, style: .blocks, updated: { val in
                arguments.toggleSetting("scopegram.showDeletedMessages", val)
                UserDefaults.standard.set(val, forKey: "chargedGram.showDeletedMessages")
            })
        case let .allowCopy(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Bypass Channel Copy Protection", value: value, sectionId: self.section, style: .blocks, updated: { val in
                arguments.toggleSetting("scopegram.allowCopyRestricted", val)
            })
        case let .secondsInTimestamp(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Exact Time with Seconds", value: value, sectionId: self.section, style: .blocks, updated: { val in
                arguments.toggleSetting("scopegram.secondsInTimestamp", val)
            })
        case let .reactions(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Quick Reactions on Hover", value: value, sectionId: self.section, style: .blocks, updated: { val in
                arguments.toggleSetting("scopegram.reactionsOnHover", val)
                UserDefaults.standard.set(val, forKey: "chargedGram.reactionsOnHover")
            })
        case let .clientCommands(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Client Commands (/fake)", value: value, sectionId: self.section, style: .blocks, updated: { val in
                arguments.toggleSetting("scopegram.clientCommands", val)
            })
        case .footer:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Anti-Delete retains messages when remote peers delete them. Exact Time displays timestamps as HH:mm:ss in message details and bubbles. Bypass Protection allows copying and forwarding from restricted channels. Client Commands allows generating local service messages via /fake."), sectionId: self.section)
        case .commandsHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "CLIENT COMMANDS", sectionId: self.section)
        case let .commandsToggle(isExpanded, count):
            return ItemListDisclosureItem(
                presentationData: presentationData,
                title: "Available Commands",
                label: isExpanded ? "Hide" : "Show (\(count))",
                sectionId: self.section,
                style: .blocks,
                disclosureStyle: .arrow,
                action: {
                    arguments.toggleCommandsExpanded()
                }
            )
        case let .commandItem(_, command, description, usage):
            return ItemListDisclosureItem(
                presentationData: presentationData,
                title: command,
                label: description,
                labelStyle: .detailText,
                sectionId: self.section,
                style: .blocks,
                disclosureStyle: .none,
                action: {
                    arguments.copyCommand(usage)
                }
            )
        case let .commandsFooter(isExpanded):
            let text = isExpanded ? "Tap any command to copy it to clipboard. Commands work locally in any chat using /fake or .fake." : "Generate local service notifications and actions via /fake or .fake."
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

public func scopegramChatSettingsController(context: AccountContext) -> ViewController {
    var presentControllerImpl: ((ViewController) -> Void)?
    var isCommandsExpanded = false
    var stateValue = 0
    let statePromise = ValuePromise<Int>(0, ignoreRepeated: false)
    
    let arguments = ScopegramChatArguments(toggleSetting: { key, val in
        UserDefaults.standard.set(val, forKey: key)
        stateValue += 1
        statePromise.set(stateValue)
    }, toggleCommandsExpanded: {
        isCommandsExpanded = !isCommandsExpanded
        stateValue += 1
        statePromise.set(stateValue)
    }, copyCommand: { usage in
        UIPasteboard.general.string = usage
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        presentControllerImpl?(UndoOverlayController(presentationData: presentationData, content: .linkCopied(title: nil, text: "Команда скопирована"), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }))
    })
    
    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get())
    |> deliverOnMainQueue
    |> map { presentationData, _ -> (ItemListControllerState, (ItemListNodeState, ScopegramChatArguments)) in
        let ud = UserDefaults.standard
        let antiDelete = ud.bool(forKey: "scopegram.showDeletedMessages") || ud.bool(forKey: "chargedGram.showDeletedMessages")
        let allowCopy = ud.bool(forKey: "scopegram.allowCopyRestricted")
        let secondsInTimestamp = ud.bool(forKey: "scopegram.secondsInTimestamp")
        let reactions = ud.bool(forKey: "scopegram.reactionsOnHover") || ud.bool(forKey: "chargedGram.reactionsOnHover")
        let clientCommands = ud.object(forKey: "scopegram.clientCommands") as? Bool ?? true
        
        var entries: [ScopegramChatEntry] = []
        entries.append(.header)
        entries.append(.antiDelete(antiDelete))
        entries.append(.allowCopy(allowCopy))
        entries.append(.secondsInTimestamp(secondsInTimestamp))
        entries.append(.reactions(reactions))
        entries.append(.clientCommands(clientCommands))
        entries.append(.footer)
        
        if clientCommands {
            entries.append(.commandsHeader)
            entries.append(.commandsToggle(isExpanded: isCommandsExpanded, count: scopegramCommandList.count))
            if isCommandsExpanded {
                for (idx, cmd) in scopegramCommandList.enumerated() {
                    entries.append(.commandItem(index: idx, command: cmd.command, description: cmd.desc, usage: cmd.usage))
                }
            }
            entries.append(.commandsFooter(isExpanded: isCommandsExpanded))
        }
        
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("Chats & Messages"),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
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
    
    let controller = ItemListController(context: context, state: signal)
    presentControllerImpl = { [weak controller] target in
        controller?.present(target, in: .current)
    }
    return controller
}

// MARK: - Category 3: Media & Files

private final class ScopegramMediaArguments {
    let toggleSetting: (String, Bool) -> Void
    init(toggleSetting: @escaping (String, Bool) -> Void) {
        self.toggleSetting = toggleSetting
    }
}

private enum ScopegramMediaSection: Int32 {
    case ttl
    case clientDetect
}

private enum ScopegramMediaEntry: ItemListNodeEntry {
    case ttlHeader
    case expiringMedia(Bool)
    case ttlFooter
    
    case detectHeader
    case detectMediaClient(Bool)
    case detectFooter
    
    var section: ItemListSectionId {
        switch self {
        case .ttlHeader, .expiringMedia, .ttlFooter:
            return ScopegramMediaSection.ttl.rawValue
        case .detectHeader, .detectMediaClient, .detectFooter:
            return ScopegramMediaSection.clientDetect.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
        case .ttlHeader: return 0
        case .expiringMedia: return 1
        case .ttlFooter: return 2
        case .detectHeader: return 3
        case .detectMediaClient: return 4
        case .detectFooter: return 5
        }
    }
    
    static func <(lhs: ScopegramMediaEntry, rhs: ScopegramMediaEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ScopegramMediaArguments
        switch self {
        case .ttlHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "SELF-DESTRUCTING MEDIA", sectionId: self.section)
        case let .expiringMedia(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Keep Disappearing Media (TTL)", value: value, sectionId: self.section, style: .blocks, updated: { val in
                arguments.toggleSetting("scopegram.saveExpiringMedia", val)
            })
        case .ttlFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Disables countdown timers on view-once photos and voice messages. When viewing TTL media, tap Save in the upper bar to save directly to Photos."), sectionId: self.section)
            
        case .detectHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "MEDIA TOOLS & INTELLIGENCE", sectionId: self.section)
        case let .detectMediaClient(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Media Client Detector", value: value, sectionId: self.section, style: .blocks, updated: { val in
                arguments.toggleSetting("scopegram.detectMediaClient", val)
            })
        case .detectFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Identifies sender device OS (iOS, Android, Desktop, Web) from audio and photo metadata. Voice notes and circular videos can be exported to Files, and audio/video files can be sent as voice/round notes via message context menu."), sectionId: self.section)
        }
    }
}

public func scopegramMediaSettingsController(context: AccountContext) -> ViewController {
    let statePromise = ValuePromise<Int>(0, ignoreRepeated: false)
    var stateValue = 0
    let arguments = ScopegramMediaArguments(toggleSetting: { key, val in
        UserDefaults.standard.set(val, forKey: key)
        stateValue += 1
        statePromise.set(stateValue)
    })
    
    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get())
    |> deliverOnMainQueue
    |> map { presentationData, _ -> (ItemListControllerState, (ItemListNodeState, ScopegramMediaArguments)) in
        let ud = UserDefaults.standard
        let expiringMedia = ud.bool(forKey: "scopegram.saveExpiringMedia")
        let detectMedia = ud.object(forKey: "scopegram.detectMediaClient") as? Bool ?? true
        
        var entries: [ScopegramMediaEntry] = []
        entries.append(.ttlHeader)
        entries.append(.expiringMedia(expiringMedia))
        entries.append(.ttlFooter)
        entries.append(.detectHeader)
        entries.append(.detectMediaClient(detectMedia))
        entries.append(.detectFooter)
        
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("Media & Files"),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: entries,
            style: .blocks,
            animateChanges: false
        )
        return (controllerState, (listState, arguments))
    }
    return ItemListController(context: context, state: signal)
}

// MARK: - Category 4: Security & Info

private final class ScopegramSecurityArguments {
    let toggleSetting: (String, Bool) -> Void
    init(toggleSetting: @escaping (String, Bool) -> Void) {
        self.toggleSetting = toggleSetting
    }
}

private enum ScopegramSecuritySection: Int32 {
    case safety
    case identity
}

private enum ScopegramSecurityEntry: ItemListNodeEntry {
    case safetyHeader
    case confirmCalls(Bool)
    case safetyFooter
    
    case infoHeader
    case showPeerId(Bool)
    case showAccountAgeAndDc(Bool)
    case infoFooter
    
    var section: ItemListSectionId {
        switch self {
        case .safetyHeader, .confirmCalls, .safetyFooter:
            return ScopegramSecuritySection.safety.rawValue
        case .infoHeader, .showPeerId, .showAccountAgeAndDc, .infoFooter:
            return ScopegramSecuritySection.identity.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
        case .safetyHeader: return 0
        case .confirmCalls: return 1
        case .safetyFooter: return 2
        case .infoHeader: return 3
        case .showPeerId: return 4
        case .showAccountAgeAndDc: return 5
        case .infoFooter: return 6
        }
    }
    
    static func <(lhs: ScopegramSecurityEntry, rhs: ScopegramSecurityEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ScopegramSecurityArguments
        switch self {
        case .safetyHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "CALL CONFIRMATION", sectionId: self.section)
        case let .confirmCalls(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Confirm Audio & Video Calls", value: value, sectionId: self.section, style: .blocks, updated: { val in
                arguments.toggleSetting("scopegram.confirmCalls", val)
                UserDefaults.standard.set(val, forKey: "chargedGram.confirmCalls")
            })
        case .safetyFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Prompts a confirmation dialog before initiating voice or video calls to prevent accidental dialing."), sectionId: self.section)
            
        case .infoHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "PROFILE INTELLIGENCE & IDS", sectionId: self.section)
        case let .showPeerId(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Show Peer ID on Profile", value: value, sectionId: self.section, style: .blocks, updated: { val in
                arguments.toggleSetting("scopegram.showPeerId", val)
            })
        case let .showAccountAgeAndDc(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Show DC & Account Age", value: value, sectionId: self.section, style: .blocks, updated: { val in
                arguments.toggleSetting("scopegram.showAccountAgeAndDc", val)
            })
        case .infoFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Shows Telegram numeric IDs, data center location (DC1-DC5), and calculated account registration year on user, channel, and group profiles. Tap any field to copy."), sectionId: self.section)
        }
    }
}

public func scopegramSecuritySettingsController(context: AccountContext) -> ViewController {
    let statePromise = ValuePromise<Int>(0, ignoreRepeated: false)
    var stateValue = 0
    let arguments = ScopegramSecurityArguments(toggleSetting: { key, val in
        UserDefaults.standard.set(val, forKey: key)
        stateValue += 1
        statePromise.set(stateValue)
    })
    
    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get())
    |> deliverOnMainQueue
    |> map { presentationData, _ -> (ItemListControllerState, (ItemListNodeState, ScopegramSecurityArguments)) in
        let ud = UserDefaults.standard
        let confirmCalls = ud.bool(forKey: "scopegram.confirmCalls") || ud.bool(forKey: "chargedGram.confirmCalls")
        let showPeerId = ud.bool(forKey: "scopegram.showPeerId")
        let showAgeDc = ud.bool(forKey: "scopegram.showAccountAgeAndDc")
        
        var entries: [ScopegramSecurityEntry] = []
        entries.append(.safetyHeader)
        entries.append(.confirmCalls(confirmCalls))
        entries.append(.safetyFooter)
        entries.append(.infoHeader)
        entries.append(.showPeerId(showPeerId))
        entries.append(.showAccountAgeAndDc(showAgeDc))
        entries.append(.infoFooter)
        
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("Security & Info"),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: entries,
            style: .blocks,
            animateChanges: false
        )
        return (controllerState, (listState, arguments))
    }
    return ItemListController(context: context, state: signal)
}

// MARK: - Category 5: Clean UI & Ads

private final class ScopegramCleanUIArguments {
    let toggleSetting: (String, Bool) -> Void
    init(toggleSetting: @escaping (String, Bool) -> Void) {
        self.toggleSetting = toggleSetting
    }
}

private enum ScopegramCleanUISection: Int32 {
    case adblock
}

private enum ScopegramCleanUIEntry: ItemListNodeEntry {
    case header
    case hideAds(Bool)
    case debugLogs(Bool)
    case footer
    
    var section: ItemListSectionId {
        return ScopegramCleanUISection.adblock.rawValue
    }
    
    var stableId: Int32 {
        switch self {
        case .header: return 0
        case .hideAds: return 1
        case .debugLogs: return 2
        case .footer: return 3
        }
    }
    
    static func <(lhs: ScopegramCleanUIEntry, rhs: ScopegramCleanUIEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ScopegramCleanUIArguments
        switch self {
        case .header:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "ADBLOCK & INTERFACE", sectionId: self.section)
        case let .hideAds(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Hide Sponsored Messages (AdBlock)", value: value, sectionId: self.section, style: .blocks, updated: { val in
                arguments.toggleSetting("scopegram.hideAds", val)
            })
        case let .debugLogs(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Debug Logging", value: value, sectionId: self.section, style: .blocks, updated: { val in
                arguments.toggleSetting("scopegram.debugLogs", val)
            })
        case .footer:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Blocks sponsored ad posts displayed at the bottom of public channels. Debug Logging enables verbose logs for client diagnostics."), sectionId: self.section)
        }
    }
}

public func scopegramCleanUISettingsController(context: AccountContext) -> ViewController {
    let statePromise = ValuePromise<Int>(0, ignoreRepeated: false)
    var stateValue = 0
    let arguments = ScopegramCleanUIArguments(toggleSetting: { key, val in
        UserDefaults.standard.set(val, forKey: key)
        stateValue += 1
        statePromise.set(stateValue)
    })
    
    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get())
    |> deliverOnMainQueue
    |> map { presentationData, _ -> (ItemListControllerState, (ItemListNodeState, ScopegramCleanUIArguments)) in
        let ud = UserDefaults.standard
        let hideAds = ud.bool(forKey: "scopegram.hideAds")
        let debugLogs = ud.bool(forKey: "scopegram.debugLogs")
        
        var entries: [ScopegramCleanUIEntry] = []
        entries.append(.header)
        entries.append(.hideAds(hideAds))
        entries.append(.debugLogs(debugLogs))
        entries.append(.footer)
        
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("Interface & AdBlock"),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: entries,
            style: .blocks,
            animateChanges: false
        )
        return (controllerState, (listState, arguments))
    }
    return ItemListController(context: context, state: signal)
}

