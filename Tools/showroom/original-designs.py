"""Original faceted designs for catalogue gaps; no historical-geometry claim.

The final vertices/faces live in each ship TOML. This authoring helper supports
repeatable design revisions; it is not a competing runtime model catalogue.
"""
import math


def coarse_design(parameters):
    """Assemble role-specific, closed convex components with outward normals."""
    vertices, faces = [], []
    family = parameters['family']
    identity = parameters['variant']
    sweep = parameters['sweep']
    sections = parameters['sections']
    pods = parameters['pods']

    def component(points, polygons, position=(0, 0, 0), scale=(1, 1, 1), angle=0):
        """Orient each closed part independently, including off-centre engines."""
        points = [[p[0]*scale[0], p[1]*scale[1], p[2]*scale[2]] for p in points]
        centre = [sum(p[i] for p in points)/len(points) for i in range(3)]
        outward = []
        for polygon in polygons:
            a,b,c = [points[k] for k in polygon[:3]]
            ab,ac = [b[i]-a[i] for i in range(3)],[c[i]-a[i] for i in range(3)]
            cross = [ab[1]*ac[2]-ab[2]*ac[1],ab[2]*ac[0]-ab[0]*ac[2],ab[0]*ac[1]-ab[1]*ac[0]]
            mid = [sum(points[k][i] for k in polygon)/len(polygon)-centre[i] for i in range(3)]
            outward.append(list(reversed(polygon)) if sum(cross[i]*mid[i] for i in range(3))<0 else polygon)
        offset = len(vertices)
        for x,y,z in points:
            vertices.append([round(x*math.cos(angle)-z*math.sin(angle)+position[0],5),round(y+position[1],5),round(x*math.sin(angle)+z*math.cos(angle)+position[2],5)])
        faces.extend([[v+offset for v in f] for f in outward])

    def pod(x,y,z,rx,ry,rz,n=6):
        """Chamfered engine/cargo nacelle with real closed end caps."""
        points = [[math.cos(i*2*math.pi/n)*rx, math.sin(i*2*math.pi/n)*ry,k*rz] for k in [-1,1] for i in range(n)]
        polygons = [list(range(n)),list(range(n,2*n))]+[[i,(i+1)%n,(i+1)%n+n,i+n] for i in range(n)]
        component(points,polygons,(x,y,z))

    def wedge(width,height,length,z=0,angle=0,x=0,y=0):
        """Eight-face tapered ship with a raised dorsal spine."""
        component([[-width,0,length*sweep],[width,0,length*sweep],[-width*.58,height,length],[width*.58,height,length],[0,height*.35,-length],[0,-height,-length*.5],[-width*.58,-height*.5,length],[width*.58,-height*.5,length]],
                  [[0,2,3,1],[0,4,2],[1,3,4],[2,4,3],[0,5,4],[1,4,5],[0,6,5],[0,2,6],[1,5,7],[1,7,3],[2,3,7,6],[5,6,7]],(x,y,z),angle=angle)

    if family in {'wedge','fighter','outrigger'}:
        if family != 'wedge':wedge(.65+(identity%5)*.06,.12+(identity%4)*.02,.65)
        if family=='fighter':
            for side in [-1,1]:
                component([[0,0,-.15],[side*1.35,0,.5],[side*.8,.06,.75],[side*.55,.12,.3],[side*.55,-.08,.3]],[[0,1,2],[0,3,1],[1,3,2],[0,2,4],[0,4,3],[2,3,4]],position=(0,0,.1))
                pod(side*.42,-.06,.5,.10,.10,.35,sections)
        elif family=='outrigger':
            for side in [-1,1]:
                pod(side*(.85+sweep/2),-.07,.2,.22,.16,.6,sections)
                pod(side*.5,0,.25,.45,.05,.10,4)
        else:
            form=parameters.get('form',identity%6)
            if form==0:
                wedge(.85,.16,.75)
                for side in [-1,1]:pod(side*.45,-.1,.65,.13,.15,.3,sections)
                pod(0,.2,.2,.08,.25,.2,4)
            elif form==1:
                # Forked catamaran: two independent bows and a transverse bridge.
                for side in [-1,1]:wedge(.28,.17,.9,z=-.1,x=side*(.44+sweep*.2))
                pod(0,0,.4,.52,.08,.18,4)
                pod(0,-.1,.7,.20,.15,.35,sections)
            elif form==2:
                # Tall central spine on a closed diamond hull.
                component([[0,0,-1],[.85+sweep,0,.1],[0,0,.8],[-.85-sweep,0,.1],[0,.38,.1],[0,-.22,.1]],
                          [[0,1,4],[1,2,4],[2,3,4],[3,0,4],[0,5,1],[1,5,2],[2,5,3],[3,5,0]])
                for side in [-1,1]:pod(side*.25,-.08,.65,.13,.13,.3,sections)
            elif form==3:
                # Raised utility hull, underslung engines and an extended nose.
                pod(0,0,0,.5,.40,.65,sections)
                wedge(.42,.16,.5,z=-.65)
                for side in [-1,1]:pod(side*.5,-.3,.4,.2,.2,.45,sections)
                pod(0,.45,.3,.13,.22,.25,4)
            elif form==4:
                # Needle fuselage with separate cruciform stabilisers.
                wedge(.24,.13,1.2)
                for side in [-1,1]:
                    pod(side*.5,0,.35,.4,.06,.14,4)
                    pod(side*.28,-.08,.8,.13,.13,.3,sections)
                pod(0,.18,.6,.08,.3,.2,4)
            else:
                # Forward-swept gull wings surrounding a narrow cockpit body.
                wedge(.3,.2,.85)
                for side in [-1,1]:
                    wedge(.50,.08,.6,z=-.15,x=side*.58,angle=side*(.45+sweep))
                    pod(side*.25,-.12,.65,.14,.16,.30,sections)
    elif family=='freighter':
        pod(0,0,0,.65,.36,.8,4+identity%3)
        wedge(.35,.16,.35,z=-.8)
        for i in range(pods):
            z=-.4+i*.8/max(1,pods-1)
            for side in [-1,1]:pod(side*.8,-.08,z,.27,.27,.26,4)
        for side in [-1,1]:pod(side*.35,0,.85,.17,.17,.25,sections)
    elif family=='liner':
        pod(0,0,0,.35,.25,.85,sections+2)
        wedge(.35,.17,.55,z=-.7)
        for side in [-1,1]:
            pod(side*.65,0,.2,.12,.12,.65,sections)
            pod(side*.35,0,.15,.30,.06,.12,4)
        pod(0,.25,.6,.10,.25,.18,4)
    elif family=='capital':
        pod(0,0,0,.30+(identity%7)*.008,.28,1.45,sections)
        for i in range(pods+1):
            for side in [-1,1]:pod(side*.60,0,-.9+i*.60,.35,.20,.20,4)
        pod(0,.45,.75,.18,.40,.30,4)
        for side in [-1,1]:pod(side*.4,-.1,1.35,.24,.24,.3,sections)
    elif family=='petals':
        pod(0,0,0,.3,.24,.30,sections)
        petals=5+identity%5
        for i in range(petals):
            a=i*2*math.pi/petals
            points=[[0,0,0],[.3,.07,.45],[.12,.12,1.15+sweep],[-.12,.12,1.15+sweep],[-.3,.07,.45],[0,-.12,.55]]
            component(points,[[0,1,2],[0,2,3],[0,3,4],[0,5,1],[1,5,2],[2,5,3],[3,5,4],[4,5,0]],angle=a)
    elif family=='ring':
        # A real open annulus: individual trapezoidal sectors, no filled disc.
        n=24
        for i in range(n):
            angles=[i*2*math.pi/n,(i+1)*2*math.pi/n]
            points=[[r*math.cos(a),y,r*math.sin(a)] for y in [-.12,.12] for r in [.75,1.0] for a in angles]
            component(points,[[0,1,3,2],[4,6,7,5],[0,4,5,1],[2,3,7,6],[0,2,6,4],[1,5,7,3]])
        pod(0,0,0,.22,.45,.22,8)
        for a in [0,math.pi/2,math.pi,math.pi*1.5]:
            component([[-.05,-.05,0],[.05,-.05,0],[.05,.05,0],[-.05,.05,0],[-.05,-.05,.85],[.05,-.05,.85],[.05,.05,.85],[-.05,.05,.85]],[[0,3,2,1],[4,5,6,7],[0,1,5,4],[1,2,6,5],[2,3,7,6],[3,0,4,7]],angle=a)
    else:
        pod(0,0,0,.45,.3,.6,sections)
        for side in [-1,1]:pod(side*.6,0,0,.18,.18,.8,4)
        pod(0,.35,-.35,.12,.35,.12,4)
    # Fit the authored shape to its documented/estimated envelope.
    for axis, extent in enumerate(parameters['dimensions']):
        low,high=min(p[axis] for p in vertices),max(p[axis] for p in vertices)
        for p in vertices:p[axis]=round((p[axis]-(high+low)/2)*extent/(high-low),5)
    return dict(vertices=vertices,faces=faces,source='Right-On Commander original geometry',license='MIT')


def design(parameters):
    """Respect the revision stored in the individual authoritative recipe."""
    if parameters.get('revision',1) < 2:
        return coarse_design(parameters)
    import importlib.util
    from pathlib import Path
    spec=importlib.util.spec_from_file_location('refined_designs',Path(__file__).with_name('refined-designs.py'))
    revised=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(revised)
    return revised.design(parameters)
