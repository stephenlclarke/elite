import Foundation

public struct ScriptModuleDefinition: Codable, Sendable {
  public let id: String
  public let path: String
  var valid: Bool {
    PackValidation.localID(id) && path.hasSuffix(".lua")
      && (try? ScriptPackLibrary.path(path)) != nil
  }
}

extension ScriptPackLibrary {
  /// The closed pack module map has no filesystem loader, bytecode loader or shared VM state.
  static func compileModules(_ definitions: [ScriptModuleDefinition], entry: Data, directory: URL)
    throws -> (source: Data, resources: [String: Data])
  {
    guard !definitions.isEmpty else { return (entry, [:]) }
    guard definitions.count <= 16, definitions.allSatisfy(\.valid) else {
      throw MissionPackError("Invalid mission module definitions.")
    }
    var source = Data(
      """
      local __mission_factories={}
      local __mission_loaded={}
      local __mission_loading={}
      local require
      require=function(name)
        if type(name)~='string' then error('Module name must be a declared string') end
        if __mission_loading[name] then error('Cyclic mission module: '..name) end
        if __mission_loaded[name] then return __mission_loaded[name] end
        local factory=__mission_factories[name]
        if not factory then error('Undeclared mission module: '..name) end
        __mission_loading[name]=true
        local result=factory()
        if type(result)~='table' then error('Mission module must return a table: '..name) end
        __mission_loaded[name]=result
        __mission_loading[name]=nil
        return result
      end

      """.utf8)
    var resources: [String: Data] = [:]
    for definition in definitions.sorted(by: { $0.id < $1.id }) {
      let bytes = try readFile(definition.path, in: directory)
      guard String(data: bytes, encoding: .utf8) != nil, !bytes.contains(0) else {
        throw MissionPackError("Mission modules must be UTF-8 text without NUL bytes.")
      }
      resources[definition.path] = bytes
      // IDs and paths were canonical ASCII identifiers before this generated source exists.
      source.append(
        Data("\n-- \(definition.path)\n__mission_factories['\(definition.id)']=function()\n".utf8))
      source.append(bytes)
      source.append(Data("\nend\n".utf8))
    }
    source.append(Data("\nreturn (function()\n".utf8))
    source.append(entry)
    source.append(Data("\nend)()\n".utf8))
    guard source.count <= 262_144 else {
      throw MissionPackError("The complete compiled mission module set exceeds256KiB.")
    }
    return (source, resources)
  }
}
