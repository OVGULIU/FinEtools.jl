module FEMMDeforWinklerModule

using FinEtools.FTypesModule
using FinEtools.FESetModule
using FinEtools.CSysModule
using FinEtools.GeoDModule
using FinEtools.FEMMBaseModule
using FinEtools.FieldModule
using FinEtools.NodalFieldModule
using FinEtools.ForceIntensityModule
using FinEtools.AssemblyModule
using FinEtools.DeforModelRedModule
using FinEtools.MatrixUtilityModule.add_nnt_ut_only!
using FinEtools.MatrixUtilityModule.complete_lt!
using FinEtools.MatrixUtilityModule.mv_product!

"""
    FEMMDeforWinkler{S<:FESet, F<:Function}

Type for normal spring support  (Winkler).
"""
# Class for heat diffusion finite element modeling machine.
type FEMMDeforWinkler{S<:FESet, F<:Function} <: FEMMAbstractBase
  geod::GeoD{S, F} # geometry data finite element modeling machine
end
export FEMMDeforWinkler

"""
    surfacenormalspringstiffness(self::FEMMDeforWinkler, assembler::A,
                  geom::NodalField{FFlt}, u::NodalField{T},
                  springconstant::FFlt) where {A<:SysmatAssemblerBase, T<:Number}

Compute the stiffness matrix of surface normal spring.
Rationale: consider continuously distributed springs between the surface of the
solid body and the 'ground', in the direction normal to the surface. If the
spring coefficient becomes large, we have an approximate method of enforcing the
normal displacement to the surface.
"""
function surfacenormalspringstiffness(self::FEMMDeforWinkler, assembler::A,
  geom::NodalField{FFlt}, u::NodalField{T},
  springconstant::FFlt) where {A<:SysmatAssemblerBase, T<:Number}
  geod = self.geod
  # Constants
  const nfes = count(geod.fes); # number of finite elements in the set
  const ndn = ndofs(u); # number of degrees of freedom per node
  const nne = nodesperelem(geod.fes); # number of nodes for element
  const sdim = ndofs(geom);            # number of space dimensions
  const mdim = manifdim(geod.fes); # manifold dimension of the element
  const Kedim = ndn*nne;             # dimension of the element matrix
  # Precompute basis f. values + basis f. gradients wrt parametric coor
  npts, Ns, gradNparams, w, pc = integrationdata(geod);
  # Prepare assembler and temporaries
  Ke = zeros(FFlt,Kedim,Kedim);                # element matrix -- used as a buffer
  conn = zeros(FInt,nne,1); # element nodes -- used as a buffer
  x = zeros(FFlt,nne,sdim); # array of node coordinates -- used as a buffer
  dofnums = zeros(FInt,1,Kedim); # degree of freedom array -- used as a buffer
  loc = zeros(FFlt,1,sdim); # quadrature point location -- used as a buffer
  J = eye(FFlt,sdim,mdim); # Jacobian matrix -- used as a buffer
  startassembly!(assembler, Kedim, Kedim, nfes, u.nfreedofs, u.nfreedofs);
  for i = 1:nfes # Loop over elements
    getconn!(geod.fes, conn, i);
    gathervalues_asmat!(geom, x, conn);# retrieve element coordinates
    fill!(Ke, 0.0); # Initialize element matrix
    for j = 1:npts # Loop over quadrature points
      At_mul_B!(loc, Ns[j], x);# Quadrature points location
      At_mul_B!(J, x, gradNparams[j]); # calculate the Jacobian matrix
      Jac = Jacobiansurface(geod, J, loc, conn, Ns[j]);
      n = surfacenormal(loc, J);# find the normal to the surface
      Nn = reshape(n*Ns[j]', Kedim, 1);# The normal n is a column vector
      add_nnt_ut_only!(Ke, Nn, springconstant*Jac*w[j])
    end # Loop over quadrature points
    complete_lt!(Ke)
    gatherdofnums!(u, dofnums, conn);# retrieve degrees of freedom
    assemble!(assembler, Ke, dofnums, dofnums);# assemble symmetric matrix
  end # Loop over elements
  return makematrix!(assembler);
end
export surfacenormalspringstiffness

function surfacenormalspringstiffness(self::FEMMDeforWinkler,
              geom::NodalField{FFlt}, u::NodalField{T},
              springconstant::FFlt) where {T<:Number}
    assembler = SysmatAssemblerSparseSymm();
    return surfacenormalspringstiffness(self, assembler, geom, u, springconstant);
end
export surfacenormalspringstiffness

"""
    surfacenormal(loc::FFltMat,J::FFltMat)

Compute local normal. This makes sense for bounding surfaces only.
"""
function  surfacenormal(loc::FFltMat, J::FFltMat)
  norml= zeros(FFlt, length(loc))
  # Produce a default normal
  if (size(J,1)==3) && (size(J,2)==2)# surface in three dimensions
    norml = cross(vec(J[:,1]),vec(J[:,2]));# outer normal to the surface
    norml = norml/norm(norml);
  elseif (size(J,1)==2)  && (size(J,2)==1)# curve in two dimensions
    norml= [J[2,1];-J[1,1]];# outer normal to the contour
    norml = norml/norm(norml);
  else
    error("No definition of normal vector");
  end
  return reshape(norml,length(norml),1) # return a column vector
end


end