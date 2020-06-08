import Foundation

final class ArgumentsHistoryModel: Model {
    var name: String
    var type: Type
    var offset: Int64 = .max
    let suffix: String
    let capturableParamNames: [String]
    let capturableParamTypes: [Type]
    let isHistoryAnnotated: Bool

    var modelType: ModelType {
        return .class
    }

    init(name: String, genericTypeParams: [ParamModel], params: [ParamModel], isHistoryAnnotated: Bool, suffix: String) {
        self.name = name + .argsHistorySuffix
        self.suffix = suffix
        self.isHistoryAnnotated = isHistoryAnnotated

        // Value contains closure is not supported.
        let capturables = params.filter { !$0.type.hasClosure }
        self.capturableParamNames = capturables.map(path: \.name)
        self.capturableParamTypes = capturables.map(path: \.type)
        
        let genericTypeNameList = genericTypeParams.map(path: \.name)
        self.type = Type.toArgumentsHistoryType(with: capturableParamTypes, typeParams: genericTypeNameList)
    }
    
    func enable(force: Bool) -> Bool {
        return (force || isHistoryAnnotated) && !capturableParamNames.isEmpty
    }
    
    func render(with identifier: String, encloser: String, useTemplateFunc: Bool = false, useMockObservable: Bool = false, enableFuncArgsHistory: Bool) -> String? {
        guard enable(force: enableFuncArgsHistory) else {
            return nil
        }
        
        switch capturableParamNames.count {
        case 1:
            return "\(identifier)\(String.argsHistorySuffix).append(\(capturableParamNames[0]))"
        case 2...:
            let paramNamesStr = capturableParamNames.joined(separator: ", ")
            return "\(identifier)\(String.argsHistorySuffix).append((\(paramNamesStr)))"
        default:
            fatalError("paramNames must not be empty.")
        }
    }
}
