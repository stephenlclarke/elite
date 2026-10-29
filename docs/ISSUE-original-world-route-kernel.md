# Share bounded navigation search with original-world routes

The existing navigation computer and staged original-world catalogue need one route-search implementation while retaining their separate caller policies. Preserve current fuel, scoring and tie behavior; validate route weights before destination exit and refuse invalid graph inputs. Original-world route preparation must use existing catalogue identities and Cartesian distances. See the [integration note](PR-original-world-route-kernel.md).
