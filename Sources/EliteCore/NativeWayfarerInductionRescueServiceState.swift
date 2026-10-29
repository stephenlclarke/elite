import Foundation

extension NativeRescueFlightState {
  func serviceRequestFitsRoute(_ request: NativeArkFuelRequest) -> Bool {
    guard
      let index = authorization.route.worldKeys.firstIndex(where: { key in
        guard let world = try? Universe.originalWorlds.world(key: key) else { return false }
        return request.offer.contact.station.system
          == SystemIdentity(galaxy: world.galaxy, system: world.system)
      }), authorization.route.distancesLY.indices.contains(index)
    else { return false }
    return request.nextHopLY == authorization.route.distancesLY[index]
  }

  func serviceShapeValid(root: NativeCrewLogAuthorization) -> Bool {
    guard fuelContacts.count <= 128, exits.count <= 128, bindings.count <= 256,
      Set(bindings.map(\.actor)).count == bindings.count,
      serviceWait == nil || dockedContact != nil,
      fuelContacts.enumerated().allSatisfy({ index, contact in
        contact.valid && contact.sequence == UInt64(index + 1)
          && contact.mission == root.manifest.mission && contact.ark == root.manifest.launch
          && contact.station.world == root.manifest.owner
          && contact.physicalTime >= authorization.physicalTime
      }),
      exits.map(\.contactSequence) == fuelContacts.filter({ $0 != dockedContact }).map(\.sequence),
      zip(fuelContacts, fuelContacts.dropFirst()).allSatisfy({
        $0.physicalTime < $1.physicalTime && $0.arkActor.visit <= $1.arkActor.visit
      })
    else { return false }
    if let dockedContact, fuelContacts.last != dockedContact { return false }
    for binding in bindings {
      guard
        fuelContacts.contains(where: {
          $0.arkActor == binding.actor && $0.physicalTime >= binding.physicalTime
        })
          || exits.contains(where: {
            $0.actor == binding.actor && $0.physicalTime == binding.physicalTime
          })
      else { return false }
      guard binding.actor.visit >= authorization.dock.actor.visit,
        binding.actor.visit < UInt64(Int64.max), binding.actor.entity > 1,
        binding.actor.entity < UInt64(Int64.max), binding.physicalTime.isFinite,
        (authorization.physicalTime...1e12).contains(binding.physicalTime),
        authorization.route.worldKeys.contains(where: { key in
          guard let world = try? Universe.originalWorlds.world(key: key) else { return false }
          return binding.actor.system == SystemIdentity(galaxy: world.galaxy, system: world.system)
        })
      else { return false }
    }
    guard
      zip(bindings, bindings.dropFirst()).allSatisfy({
        $0.physicalTime <= $1.physicalTime
          && ($0.actor.visit < $1.actor.visit
            || ($0.actor.visit == $1.actor.visit && $0.actor.entity < $1.actor.entity))
      })
    else { return false }
    for exit in exits {
      guard let contact = fuelContacts.first(where: { $0.sequence == exit.contactSequence }),
        exit.actor != contact.arkActor, exit.actor.system == contact.station.system,
        exit.actor.visit >= contact.arkActor.visit, exit.physicalTime.isFinite,
        (contact.physicalTime...1e12).contains(exit.physicalTime),
        bindings.contains(.init(actor: exit.actor, physicalTime: exit.physicalTime))
      else { return false }
    }
    return true
  }
}
