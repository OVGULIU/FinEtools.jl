module MeshHexahedronModule

using FinEtools.FTypesModule
using FinEtools.FESetModule
using FinEtools.FENodeSetModule
using FinEtools.MeshUtilModule
using FinEtools.MeshModificationModule
using FinEtools.MeshSelectionModule

"""
    H8block(Length::FFlt, Width::FFlt, Height::FFlt, nL::FInt, nW::FInt, nH::FInt)

Make  a mesh  of a 3D block consisting of  eight node hexahedra.

Length, Width, Height= dimensions of the mesh in Cartesian coordinate axes,
smallest coordinate in all three directions is  0 (origin)
nL, nW, nH=number of elements in the three directions
"""

function H8block(Length::FFlt, Width::FFlt, Height::FFlt, nL::FInt, nW::FInt, nH::FInt)
  return H8blockx(collect(linspace(0, Length, nL+1)),
  collect(linspace(0, Width, nW+1)), collect(linspace(0, Height, nH+1)));
end
export H8block

"""
    H8blockx(xs::FFltVec, ys::FFltVec, zs::FFltVec)

Graded mesh of a 3-D block of H8 finite elements.
"""
function H8blockx(xs::FFltVec, ys::FFltVec, zs::FFltVec)
  nL =length(xs)-1;
  nW =length(ys)-1;
  nH =length(zs)-1;

  nnodes=(nL+1)*(nW+1)*(nH+1);
  xyz =zeros(FFlt, nnodes, 3);
  ncells=(nL)*(nW)*(nH);
  conns =zeros(FInt, ncells, 8);


  # first go along Length,  then Width,  and finally Height
  function node_numbers(i, j, k, nL, nW, nH)
    f=(k-1)*((nL+1)*(nW+1))+(j-1)*(nL+1)+i;
    nn=[f (f+1)  f+(nL+1)+1 f+(nL+1)];
    nn=[nn nn+((nL+1)*(nW+1))];
  end

  f=1;
  for k=1:(nH+1)
    for j=1:(nW+1)
      for i=1:(nL+1)
        xyz[f, :]=[xs[i] ys[j] zs[k]];
        f=f+1;
      end
    end
  end

  gc=1;
  for i=1:nL
    for j=1:nW
      for k=1:nH
        nn=node_numbers(i, j, k, nL, nW, nH);
        conns[gc, :]=nn;
        gc=gc+1;
      end
    end
  end
  # create the nodes
  fens = FENodeSetModule.FENodeSet(xyz);
  # Create the finite elements
  fes = FESetModule.FESetH8(conns);

  return fens, fes;
end
export H8blockx


# Create a solid mesh of 1/8 of the sphere of "radius".
#
# function [fens, gcells]=H8_sphere(radius, nrefine)
#
# Create a mesh of 1/8 of the sphere of "radius". The  mesh will consist of
# four hexahedral elements if "nrefine==0",  or more if "nrefine>0".
# "nrefine" is the number of bisections applied  to refine the mesh.
#
function H8sphere(radius::FFlt, nrefine::FInt)
    a=sqrt(2.0)/2.0;
    b=1.0/sqrt(3.0);
    c=0.6*a;
    d=0.6*b;
    z= 0.0;
    h= 0.5;
    o= 1.0;
    xyz= [z  z  z;
        h  z  z;
        c  c  z;
        z  h  z;
        z  z  h;
        c  z  c;
        d  d  d;
        z  c  c;
        z  z  o;
        a  z  a;
        o  z  z;
        a  a  z;
        z  o  z;
        z  a  a;
        b  b  b]*radius;
    conns=[1  2  3  4  5  6  7  8;
        2  11  12  3  6  10  15  7;
        4  3  12  13  8  7  15  14;
        5  6  7  8  9  10  15  14];

    fens = FENodeSetModule.FENodeSet(xyz);
    fes = FESetModule.FESetH8(conns);
    for i = 1:nrefine
        fens, fes = H8refine(fens, fes);
        bg = MeshModificationModule.meshboundary(fes);
        l = MeshSelectionModule.selectelem(fens, bg, facing=true,  direction=[1, 1, 1]);
        cn = MeshSelectionModule.connectednodes(FESetModule.subset(bg, l))   ;
        for j=1:length(cn)
            fens.xyz[cn[j], :]=fens.xyz[cn[j], :]*radius/norm(fens.xyz[cn[j], :]);
        end
    end
     return fens,  fes
end
export H8sphere

function H8refine(fens::FENodeSetModule.FENodeSet,  fes::FESetModule.FESetH8)
# Refine a mesh of H8 hexahedrals by octasection.
#
# function [fens, fes] = H8_refine(fens, fes)
#
# Arguments and
# Output:
# fens= finite element node set
# fes = finite element set
#
# Examples:
#
#     xyz = [3,  1,  6; -5,  2,  1];
#     [fens, fes] = H8_hexahedron(xyz, 1, 2, 3);
#     drawmesh({fens, fes}, 'fes', 'facecolor', 'red');
#     [fens, fes] = H8_refine(fens, fes);
#     figure;
#     drawmesh({fens, fes}, 'fes', 'facecolor', 'm');

    fens, fes = H8toH27(fens, fes);
    conn=fes.conn;
    nconn=zeros(FInt, 8*size(conn, 1), 8);
    nc=1;
    for i= 1:size(conn, 1)
        conn27=conn[i, :];
        nconn[nc, :] =conn27[[1, 9, 21, 12, 17, 22, 27, 25]];        nc= nc+ 1;
        nconn[nc, :] =conn27[[9, 2, 10, 21, 22, 18, 23, 27]];        nc= nc+ 1;
        nconn[nc, :] =conn27[[21, 10, 3, 11, 27, 23, 19, 24]];        nc= nc+ 1;
        nconn[nc, :] =conn27[[12, 21, 11, 4, 25, 27, 24, 20]];        nc= nc+ 1;
        nconn[nc, :] =conn27[[17, 22, 27, 25, 5, 13, 26, 16]];        nc= nc+ 1;
        nconn[nc, :] =conn27[[22, 18, 23, 27, 13, 6, 14, 26]];        nc= nc+ 1;
        nconn[nc, :] =conn27[[27, 23, 19, 24, 26, 14, 7, 15]];        nc= nc+ 1;
        nconn[nc, :] =conn27[[25, 27, 24, 20, 16, 26, 15, 8]];        nc= nc+ 1;
    end

    fes=FESetModule.FESetH8(nconn);
    return fens,  fes
end
export H8refine

function   H8toH27(fens::FENodeSetModule.FENodeSet,  fes::FESetModule.FESetH8)
# Convert a mesh of hexahedra H8 to hexahedra H27.
#
# function [fens, fes] = H8_to_H27(fens, fes)
#
# Arguments and
# Output:
# fens= finite element node set
# fes = finite element set
#
    nedges=12;
    nfaces=6;
    ec = [1   2; 2   3; 3   4; 4   1; 5   6; 6   7; 7   8; 8   5; 1   5; 2   6; 3   7; 4   8;];
    fc = [1     4     3     2;
        1     2     6     5;
        2     3     7     6;
        3     4     8     7;
        4     1     5     8;
        6     7     8     5];
    conns = fes.conn;
    labels = deepcopy(fes.label)
    # Additional node numbers are numbered from here
    newn=FENodeSetModule.count(fens)+1;
    # make a search structure for edges
    edges=MeshUtilModule.makecontainer();
    for i= 1:size(conns, 1)
        conn = conns[i, :];
        for J = 1:nedges
            ev=conn[ec[J, :]];
            newn = MeshUtilModule.addhyperface!(edges,  ev,  newn);
        end
    end
    # make a search structure for faces
    faces=MeshUtilModule.makecontainer();
    for i= 1:size(conns, 1)
        conn = conns[i, :];
        for J = 1:nfaces
            fv=conn[fc[J, :]];
            newn = MeshUtilModule.addhyperface!(faces,  fv,  newn);
        end
    end
    # make a search structure for volumes
    volumes=MeshUtilModule.makecontainer();
    for i= 1:size(conns, 1)
      conn = conns[i, :];
      newn = MeshUtilModule.addhyperface!(volumes,  conn,  newn);
    end
    xyz1 =fens.xyz;             # Pre-existing nodes
   # Allocate for vertex nodes plus edge nodes plus face nodes
    xyz =zeros(FFlt, newn-1, 3);
    xyz[1:size(xyz1, 1), :] = xyz1; # existing nodes are copied over
    # calculate the locations of the new nodes
    # and construct the new nodes
    for i in keys(edges)
        C=edges[i];
        for J = 1:length(C)
          ix = vec([item for item in C[J].o])
          push!(ix,  i)
          xyz[C[J].n, :]=mean(xyz[ix, :], 1);
        end
    end
   # calculate the locations of the new nodes
    # and construct the new nodes
    for i in keys(faces)
        C=faces[i];
        for J = 1:length(C)
          ix = vec([item for item in C[J].o])
          push!(ix,  i)
          xyz[C[J].n, :] = mean(xyz[ix, :], 1);
        end
    end
    # calculate the locations of the new nodes
    # and construct the new nodes
    for i in keys(volumes)
       C=volumes[i];
        for J = 1:length(C)
          ix = vec([item for item in C[J].o])
          push!(ix,  i)
          xyz[C[J].n, :] = mean(xyz[ix, :], 1);
        end
    end
     # construct new geometry cells
    nconns =zeros(FInt, size(conns, 1), 27);
    nc=1;
    for i= 1:size(conns, 1)
        conn = conns[i, :];
        econn=zeros(FInt, 1, nedges);
        for J = 1:nedges
            ev=conn[ec[J, :]];
            h, n=MeshUtilModule.findhyperface!(edges,  ev);
            econn[J]=n;
        end
        fconn=zeros(FInt, 1, nfaces);
        for J = 1:nfaces
            fv=conn[fc[J, :]];
            h, n=MeshUtilModule.findhyperface!(faces,  fv);
            fconn[J]=n;
        end
        h, n=MeshUtilModule.findhyperface!(volumes,  conn);
        vconn=n;
        nconns[nc, :] =vcat(vec(conn),  vec(econn),  vec(fconn),  vec([vconn]))
        nc= nc+ 1;
    end
    fens =FENodeSetModule.FENodeSet(xyz);
    fes = FESetModule.FESetH27(nconns) ;
    setlabel!(fes, labels);
    return fens, fes;
end
export H8toH27

function H8hexahedron(xyz::FFltMat, nL::FInt, nW::FInt, nH::FInt;block_mesh_handle=nothing)
# Mesh of a general hexahedron given by the location of the vertices.
#
# function [fens, fes] = H8_hexahedron(xyz, nL, nW, nH, block_mesh_handle)
#
# xyz = One vertex location per row; Either two rows (for a rectangular
#      block given by the its corners),  or eight rows (general hexahedron).
# nL,  nW,  nH = Divided into elements: nL,  nW,  nH in the first,  second,  and
#      third direction.
# Optional argument:
# block_mesh_handle = function handle of the block-generating mesh function
#      (having the signature of the function H8_block()).
#
# Output:
# fens= finite element node set
# fes = finite element set
#
#
# Examples:
#
#     xyz = [3,  1,  6; -5,  2,  1];
#     [fens, fes] = H8_hexahedron(xyz, 12, 3, 4);
#     drawmesh({fens, fes}, 'fes', 'facecolor', 'red'); hold on
#
#     A=[0, 0, 0]; B=[0, 0, 2]; C=[0, 3, 2]; D=[0, 3, 0];
#     E=[5, 0, 0]; F=[5, 0, 2]; G=[5, 3, 2]; H=[5, 3, 0];
#     P=[3.75, 0, 0];
#     [fens, fes] = H8_hexahedron([A;P;(D+H)/2;D;B;(B+F)/2;(C+G)/2;C], 2, 3, 4, []);
#     drawmesh({fens, fes}, 'fes', 'facecolor', 'red'); hold on
#
#     A=[0, 0, 0]; B=[0, 0, 2]; C=[0, 3, 2]; D=[0, 3, 0];
#     E=[5, 0, 0]; F=[5, 0, 2]; G=[5, 3, 2]; H=[5, 3, 0];
#     P=[3.75, 0, 0];
#     [fens, fes] = H8_hexahedron([A;P;(D+H)/2;D;B;(B+F)/2;(C+G)/2;C], 1, 2, 3, @H20_block);
#     drawmesh({fens, fes}, 'nodes', 'fes', 'facecolor', 'none'); hold on

    npts=size(xyz, 1);
    if npts==2
        lo=minimum(xyz, 1);
        hi=maximum(xyz, 1);
        xyz=[lo[1]  lo[2]  lo[3];
            hi[1]  lo[2]  lo[3];
            hi[1]  hi[2]  lo[3];
            lo[1]  hi[2]  lo[3];
            lo[1]  lo[2]  hi[3];
            hi[1]  lo[2]  hi[3];
            hi[1]  hi[2]  hi[3];
            lo[1]  hi[2]  hi[3]];
    elseif npts!=8
        error("Need 2 or 8 points");
    end

    if block_mesh_handle==nothing
        block_mesh_handle =H8block; # default block type
    end

    fens, fes= block_mesh_handle(2.0, 2.0, 2.0, nL, nW, nH);

    dummy = FESetModule.FESetH8(reshape(collect(1:8), 1, 8))
    pxyz=fens.xyz;
    for i=1:FENodeSetModule.count(fens)
        N = FESetModule.bfun(dummy, pxyz[i, :]-1.0);# shift coordinates by -1
        pxyz[i, :] =N'*xyz;
    end
    fens.xyz=pxyz;

    return fens, fes;
end
export H8hexahedron

function H27block(Length::FFlt, Width::FFlt, Height::FFlt, nL::FInt, nW::FInt, nH::FInt)
  # Mesh of a 3-D block of H27 finite elements
  #
  # Arguments:
  # Length, Width, Height= dimensions of the mesh in Cartesian coordinate axes,
  # smallest coordinate in all three directions is  0 (origin)
  # nL, nW, nH=number of elements in the three directions
  #
  # Range in xyz =<0, Length> x <0, Width> x <0, Height>
  # Divided into elements: nL,  nW,  nH in the first,  second,  and
  # third direction (x, y, z). Finite elements of type H27.
  #
  # Output:
  # fens= finite element node set
  # fes = finite element set
  #
  #
  # Examples:
  #
  #     [fens, fes] = H27_block(2, 3, 4,  1, 2, 3);
  #     drawmesh({fens, fes}, 'nodes', 'fes', 'facecolor', 'none'); hold on
  #
  # See also: H8_block,  H8_to_H27
  #
  fens, fes = H8block(Length, Width, Height, nL, nW, nH);
  fens, fes = H8toH27(fens, fes);
  return fens, fes
end
export H27block

function doextrude(fens, fes::FESetQ4, nLayers, extrusionh)
  nn1=count(fens);
  nnt=nn1*nLayers;
  ngc=count(fes)*nLayers;
  hconn=zeros(FInt, ngc, 8);
  xyz =zeros(FFlt, nn1*(nLayers+1), 3);
  for j=1:nn1
    xyz[j, :] =extrusionh(fens.xyz[j, :], 0);
  end
  for k=1:nLayers
    for j=1:nn1
      f=j+k*nn1;
      xyz[f, :] =extrusionh(fens.xyz[j, :], k);
    end
  end

  gc=1;
  for k=1:nLayers
    for i=1:count(fes)
      hconn[gc, :]=[fes.conn[i, :]+(k-1)*nn1 fes.conn[i, :]+k*nn1];
      gc=gc+1;
    end
  end
  efes = FESetModule.FESetH8(hconn);
  efens = FENodeSetModule.FENodeSet(xyz);
  return efens, efes
end

"""
    H8extrudeQ4(fens::FENodeSet,  fes::FESetQ4, nLayers::FInt, extrusionh::Function)

Extrude a mesh of quadrilaterals into a mesh of hexahedra (H8).
"""
function H8extrudeQ4(fens::FENodeSet,  fes::FESetQ4, nLayers::FInt,
  extrusionh::F) where {F<:Function}
  id = vec([i for i in 1:count(fens)])
  cn=connectednodes(fes);
  id[cn[:]]=vec([i for i in 1:length(cn)]);
  q4fes= deepcopy(fes);
  updateconn!(q4fes, id);
  q4fens = FENodeSetModule.FENodeSet(fens.xyz[cn[:], :]);
  h8fens, h8fes= doextrude(q4fens, q4fes, nLayers, extrusionh);
  return h8fens, h8fes
end
export H8extrudeQ4

function H8spheren(radius::FFlt, nperradius::FInt)
# Create a solid mesh of 1/8 of sphere.
#
# Create a solid mesh of 1/8 of the sphere of "radius",  with nperradius
# elements per radius.
#
# function [fens, fes]=H8_sphere_n(radius, nperradius)
#
# Create a mesh of 1/8 of the sphere of "radius". The  mesh will consist of
# 4*(nperradius/2)^2 hexahedral elements.
#
# Output:
# fens= finite element node set
# fes = finite element set
#
# Examples:
#     [fens, fes]=H8_sphere_n(22.3, 3);
#     drawmesh({fens, fes}, 'fes', 'facecolor', 'red'); hold on
#
# See also: H8_sphere
if (mod(nperradius, 2) != 0)
  nperradiu = nperradius+1;
end
nL = ceil(FInt, nperradius/2); nW=nL; nH=nL;

a=sqrt(2.0)/2.0;
b=1.0/sqrt(3.0);
c=0.6*a;
d=0.6*b;
z= 0.0;
h= 0.5;
o= 1.0;
xyz= [z  z  z;
      h  z  z;
      c  c  z;
      z  h  z;
      z  z  h;
      c  z  c;
      d  d  d;
      z  c  c;
      z  z  o;
      a  z  a;
      o  z  z;
      a  a  z;
      z  o  z;
      z  a  a;
      b  b  b]*radius;
conns=[1  2  3  4  5  6  7  8;
       2  11  12  3  6  10  15  7;
       4  3  12  13  8  7  15  14;
       5  6  7  8  9  10  15  14];
tolerance=radius*1.0e-6;

# fens = FENodeSetModule.FENodeSet(xyz= xyz);
#   fes = FESetModule.FESetH8(conn=conns);
fens, fes = H8hexahedron(xyz[conns[1, :][:], :], nL, nW, nH);
fens1, fes1 = H8hexahedron(xyz[conns[2, :][:], :], nL, nW, nH);
fens, fes1, fes2 = mergemeshes(fens1,  fes1,  fens,  fes,  tolerance);
fes=cat(fes1, fes2);
fens1, fes1 = H8hexahedron(xyz[conns[3, :][:], :], nL, nW, nH);
fens, fes1, fes2 = mergemeshes(fens1,  fes1,  fens,  fes,  tolerance);
fes=cat(fes1, fes2);
fens1, fes1 = H8hexahedron(xyz[conns[4, :][:], :], nL, nW, nH);
fens, fes1, fes2 = mergemeshes(fens1,  fes1,  fens,  fes,  tolerance);
fes=cat(fes1, fes2);

xyz = deepcopy(fens.xyz);
layer = oftype(1.0, Inf) + zeros(FFlt, size(xyz,  1), 1);
  conn = deepcopy(fes.conn);
  bg = meshboundary(fes);
  l = selectelem(fens, bg; facing=true,  direction=[1. 1. 1.]);
  cn = connectednodes(subset(bg, l))   ;
  layer[cn] = 1;
  for j = 1:nperradius-1
    for k = 1:size(conn, 1)
      ll = layer[conn[k, :]];
      ml = minimum(ll);
      if (ml==j)
        ix = isinf.(ll);
        ll[ix] = j+1;
        layer[conn[k, :]] = ll;
      end
    end
  end
  nxyz = deepcopy(xyz);
  for j = 1:size(xyz, 1)
    if (!isinf.(layer[j]))
      nxyz[j, :] = nxyz[j, :]*(nperradius-layer[j]+1)/nperradius*radius/norm(nxyz[j, :]);
    end
  end
  s =  collect(linspace(0.,  1.,  length(layer)));
  # println("s=$s")
  # println("layer = $layer")
  for j = 1:size(xyz, 1)
    ell = layer[j]
    # show(ell)
    if (!isinf.(ell))
      ell = Int(ell)
      nxyz[j, :] = s[ell]*xyz[j, :] + (1-s[ell])*nxyz[j, :];
    end
  end
  fens.xyz = deepcopy(nxyz);
  return fens, fes
end
export H8spheren

function H20block(Length::FFlt, Width::FFlt, Height::FFlt, nL::FInt, nW::FInt, nH::FInt)
    # Mesh of a 3-D block of H20 finite elements
    #
    # Arguments:
    # Length, Width, Height= dimensions of the mesh in Cartesian coordinate axes,
    # smallest coordinate in all three directions is  0 (origin)
    # nL, nW, nH=number of elements in the three directions
    #
    # Range in xyz =<0, Length> x <0, Width> x <0, Height>
    # Divided into elements: nL,  nW,  nH in the first,  second,  and
    # third direction (x, y, z). Finite elements of type H20.
    #
    # Output:
    # fens= finite element node set
    # fes = finite element set
    #
    #
    # Examples:
    #     [fens, fes] = H20_block(2, 3, 4,  1, 2, 3);
    #     drawmesh({fens, fes}, 'nodes', 'fes', 'facecolor', 'none'); hold on
    #
    # See also: H8_block,  H8_to_H20
    #
    fens, fes = H8block(Length, Width, Height, nL, nW, nH);
    fens, fes = H8toH20(fens, fes);
end
export H20block

"""
    H8toH20(fens::FENodeSetModule.FENodeSet,  fes::FESetModule.FESetH8)

Convert a mesh of hexahedra H8 to hexahedra H20.
"""
function   H8toH20(fens::FENodeSetModule.FENodeSet,  fes::FESetModule.FESetH8)
  nedges=12;
  ec = [1   2; 2   3; 3   4; 4   1; 5   6; 6   7; 7   8; 8   5; 1   5; 2   6; 3   7; 4   8;];
  conns = fes.conn;
  labels = deepcopy(fes.label)
  # Additional node numbers are numbered from here
  newn=FENodeSetModule.count(fens)+1;
  # make a search structure for edges
  edges=MeshUtilModule.makecontainer();
  for i= 1:size(conns, 1)
    conn = conns[i, :];
    for J = 1:nedges
      ev=conn[ec[J, :]];
      newn = MeshUtilModule.addhyperface!(edges,  ev,  newn);
    end
  end
  xyz1 =fens.xyz;             # Pre-existing nodes
  # Allocate for vertex nodes plus edge nodes plus face nodes
  xyz =zeros(FFlt, newn-1, 3);
  xyz[1:size(xyz1, 1), :] = xyz1; # existing nodes are copied over
  # calculate the locations of the new nodes
  # and construct the new nodes
  for i in keys(edges)
    C=edges[i];
    for J = 1:length(C)
      ix = vec([item for item in C[J].o])
      push!(ix,  i) # Add the anchor point as well
      xyz[C[J].n, :] = mean(xyz[ix, :], 1);
    end
  end
  # construct new geometry cells
  nconns =zeros(FInt, size(conns, 1), 20);
  nc=1;
  for i= 1:size(conns, 1)
    conn = conns[i, :];
    econn=zeros(FInt, 1, nedges);
    for J = 1:nedges
      ev=conn[ec[J, :]];
      h, n=MeshUtilModule.findhyperface!(edges,  ev);
      econn[J]=n;
    end
    nconns[nc, :] =vcat(vec(conn),  vec(econn))
    nc= nc+ 1;
  end
  fens =FENodeSetModule.FENodeSet(xyz);
  fes = FESetModule.FESetH20(nconns) ;
  setlabel!(fes, labels);
  return fens, fes;
end
export H8toH20

# Construct arrays to describe a hexahedron mesh created from voxel image.
#
# img = 3-D image (array),  the voxel values  are arbitrary
# voxval =range of voxel values to be included in the mesh,
# voxval =  [minimum value,  maximum value].  Minimum value == maximum value is
# allowed.
# Output:
# t = array of hexahedron connectivities,  one hexahedron per row
# v =Array of vertex locations,  one vertex per row
function H8voximggen{DataT<:Number}(img::Array{DataT, 3}, voxval::Array{DataT, 1})
   M=size(img,  1); N=size(img,  2); P=size(img,  3);

     function find_nonempty(minvoxval, maxvoxval)
        Nvoxval=0
        for I= 1:M
            for J= 1:N
                for K= 1:P
                    if (img[I, J, K]>=minvoxval) && (img[I, J, K]<=maxvoxval)
                        Nvoxval=Nvoxval+1
                    end
                end
            end
        end
        return Nvoxval
    end
    minvoxval= minimum(voxval)  # include voxels at or above this number
    maxvoxval= maximum(voxval)  # include voxels at or below this number
    Nvoxval =find_nonempty(minvoxval, maxvoxval) # how many "full" voxels are there?

    # Allocate output arrays
    h =zeros(FInt, Nvoxval, 8);
    v =zeros(FInt, (M+1)*(N+1)*(P+1), 3);
    hmid =zeros(FInt, Nvoxval);

    Slice =zeros(FInt, 2, N+1, P+1); # auxiliary buffer
    function find_vertex(I, IJK)
        vidx = zeros(FInt, 1, size(IJK, 1));
        for r= 1:size(IJK, 1)
            if (Slice[IJK[r, 1], IJK[r, 2], IJK[r, 3]]==0)
                nv=nv+1;
                v[nv, :] =IJK[r, :]; v[nv, 1] += I-1;
                Slice[IJK[r, 1], IJK[r, 2], IJK[r, 3]] =nv;
            end
            vidx[r] =Slice[IJK[r, 1], IJK[r, 2], IJK[r, 3]];
        end
        return vidx
    end
    function store_hex(I, J, K)
        locs =[1 J K;1+1 J K;1+1 J+1 K;1 J+1 K;1 J K+1;1+1 J K+1;1+1 J+1 K+1;1 J+1 K+1];
        vidx = find_vertex(I, locs);
        nh =nh +1;
        h[nh, :] =vidx;
        hmid[nh] =img[I, J, K];
    end

    nv =0;                      # number of vertices
    nh =0;                      # number of elements
    for I= 1:M
        for J= 1:N
            for K= 1:P
                if  (img[I, J, K]>=minvoxval) && (img[I, J, K]<=maxvoxval)
                    store_hex(I, J, K);
                end
            end
        end
        Slice[1, :, :] =Slice[2, :, :] ;
        Slice[2, :, :] =0;
    end
    # Trim output arrays
    v=v[1:nv, :];
    h=h[1:nh, :] ;
    hmid=hmid[1:nh] ;

    return h, v, hmid
end


function H8voximg{DataT<:Number}(img::Array{DataT, 3}, voxdims::FFltVec,
  voxval::Array{DataT, 1})
  h, v, hmid= H8voximggen(img, voxval)
  xyz=zeros(FFlt, size(v, 1), 3)
  for j=1:size(v, 1)
    for k=1:3
      xyz[j, k]=v[j, k]*voxdims[k]
    end
  end
  fens =FENodeSetModule.FENodeSet(xyz);
  fes = FESetModule.FESetH8(h) ;
  setlabel!(fes, hmid)
  return fens, fes;
end
export H8voximg

"""
    H8compositeplatex(xs::FFltVec, ys::FFltVec, ts::FFltVec, nts::FIntVec)

H8 mesh for a layered block (composite plate) with specified in plane coordinates.

xs,ys =Locations of the individual planes of nodes.
ts= Array of layer thicknesses,
nts= array of numbers of elements per layer

The finite elements of each layer are labeled with the layer number, starting
from 1.
"""
function H8compositeplatex(xs::FFltVec, ys::FFltVec, ts::FFltVec, nts::FIntVec)
tolerance = minimum(abs.(ts))/maximum(nts)/10.;
@assert length(ts) >= 1
layer = 1
zs = collect(linspace(0,ts[layer],nts[layer]+1))
fens, fes = H8blockx(xs, ys, zs);
setlabel!(fes, layer);
for layer = 2:length(ts)
  zs = collect(linspace(0,ts[layer],nts[layer]+1))
  fens1, fes1 = H8blockx(xs, ys, zs);
  setlabel!(fes1, layer);
  fens1.xyz[:, 3] += sum(ts[1:layer-1]);
  fens, fes1, fes2 = mergemeshes(fens1, fes1, fens, fes, tolerance);
  fes = cat(fes1,fes2);
end
return fens,fes
end
export H8compositeplatex

end