module mmmmPoiss_06122017
using FinEtools
using Base.Test
function test()

  # println("""
  #
  # Heat conduction example described by Amuthan A. Ramabathiran
  # http://www.codeproject.com/Articles/579983/Finite-Element-programming-in-Julia:
  # Unit square, with known temperature distribution along the boundary,
  # and uniform heat generation rate inside.  Mesh of regular linear TRIANGLES,
  # in a grid of 1000 x 1000 edges (2M triangles, 1M degrees of freedom).
  # Version: 05/29/2017
  # """
  # )
  t0 = time()

  A = 1.0 # dimension of the domain (length of the side of the square)
  thermal_conductivity = eye(2,2); # conductivity matrix
  Q = -6.0; # internal heat generation rate
  function getsource!(forceout::FFltVec, XYZ::FFltMat, tangents::FFltMat, fe_label::FInt)
    forceout[1] = Q; #heat source
  end
  tempf(x) = (1.0 + x[:,1].^2 + 2*x[:,2].^2);#the exact distribution of temperature
  N = 100;# number of subdivisions along the sides of the square domain


  # println("Mesh generation")
  fens,fes =T3block(A, A, N, N)

  geom = NodalField(fens.xyz)
  Temp = NodalField(zeros(size(fens.xyz,1),1))

  # println("Searching nodes  for BC")
  l1 = selectnode(fens; box=[0. 0. 0. A], inflate = 1.0/N/100.0)
  l2 = selectnode(fens; box=[A A 0. A], inflate = 1.0/N/100.0)
  l3 = selectnode(fens; box=[0. A 0. 0.], inflate = 1.0/N/100.0)
  l4 = selectnode(fens; box=[0. A A A], inflate = 1.0/N/100.0)
  List = vcat(l1, l2, l3, l4)
  setebc!(Temp, List, true, 1, tempf(geom.values[List,:])[:])
  applyebc!(Temp)
  numberdofs!(Temp)

  t1 = time()

  material = MatHeatDiff(thermal_conductivity)

  femm = FEMMHeatDiff(GeoD(fes, TriRule(1), 100.), material)


  # println("Conductivity")
  K = conductivity(femm, geom, Temp)
  # println("Nonzero EBC")
  F2 = nzebcloadsconductivity(femm, geom, Temp);
  # println("Internal heat generation")
  # fi = ForceIntensity(FFlt, getsource!);# alternative  specification
  fi = ForceIntensity(FFlt[Q]);
  F1 = distribloads(femm, geom, Temp, fi, 3);

  # println("Factorization")
  K = cholfact(K)
  # println("Solution of the factorized system")
  U = K\(F1+F2)
  scattersysvec!(Temp,U[:])

  # println("Total time elapsed = $(time() - t0) [s]")
  # println("Solution time elapsed = $(time() - t1) [s]")

  Error= 0.0
  for k=1:size(fens.xyz,1)
    Error = Error+abs.(Temp.values[k,1]-tempf(reshape(fens.xyz[k,:], (1,2))))
  end
  # println("Error =$Error")


  # File =  "a.vtk"
  # MeshExportModule.vtkexportmesh (File, fes.conn, [geom.values Temp.values], MeshExportModule.T3; scalars=Temp.values, scalars_name ="Temperature")

  @test Error[1]<1.e-5

  true
end
end
using mmmmPoiss_06122017
mmmmPoiss_06122017.test()

module mmmmannulus_Q4_example_algo
using FinEtools
using Base.Test
function test()
  # println("""
  # Annular region, ingoing and outgoing flux. Temperature at one node prescribed.
  # Minimum/maximum temperature ~(+/-)0.500.
  # Mesh of serendipity quadrilaterals.
  # This version uses the FinEtools algorithm module.
  # Version: 05/29/2017
  # """)

  t0 = time()

  kappa = 0.2*[1.0 0; 0 1.0]; # conductivity matrix
  magn = 0.06;# heat flux along the boundary
  rin =  1.0;#internal radius

  rex =  2.0; #external radius
  nr = 3; nc = 40;
  Angle = 2*pi;
  thickness =  1.0;
  tolerance = min(rin/nr,  rin/nc/2/pi)/10000;

  fens, fes = Q4annulus(rin, rex, nr, nc, Angle)
  fens, fes = mergenodes(fens,  fes,  tolerance);
  edge_fes = meshboundary(fes);

  # At a single point apply an essential boundary condition (pin down the temperature)
  l1  = selectnode(fens; box=[0.0 0.0 -rex -rex],  inflate = tolerance)
  essential1 = FDataDict("node_list"=>l1, "temperature"=>0.0)

  # The flux boundary condition is applied at two pieces of surface
  # Side 1
  l1 = selectelem(fens, edge_fes, box=[-1.1*rex -0.9*rex -0.5*rex 0.5*rex]);
  el1femm = FEMMBase(GeoD(subset(edge_fes, l1),  GaussRule(1, 2)))
  fi = ForceIntensity(FFlt[-magn]);#entering the domain
  flux1 = FDataDict("femm"=>el1femm, "normal_flux"=>-magn) # entering the domain
  # Side 2
  l2=selectelem(fens,edge_fes,box=[0.9*rex 1.1*rex -0.5*rex 0.5*rex]);
  el2femm = FEMMBase(GeoD(subset(edge_fes, l2),  GaussRule(1, 2)))
  flux2 = FDataDict("femm"=>el2femm, "normal_flux"=>+magn) # leaving the domain

  material = MatHeatDiff(kappa)
  femm = FEMMHeatDiff(GeoD(fes,  GaussRule(2, 2)),  material)
  region1 = FDataDict("femm"=>femm)

  # Make model data
  modeldata = FDataDict("fens"=>fens,
  "regions"=>[region1], "essential_bcs"=>[essential1],
  "flux_bcs"=>[flux1, flux2]);

  # Call the solver
  modeldata = FinEtools.AlgoHeatDiffModule.steadystate(modeldata)
  geom=modeldata["geom"]
  Temp=modeldata["temp"]
  # println("Minimum/maximum temperature= $(minimum(Temp.values))/$(maximum(Temp.values)))")

  # println("Total time elapsed = ",time() - t0,"s")

  # # Postprocessing
  # vtkexportmesh("annulusmod.vtk", fes.conn, [geom.values Temp.values],
  # FinEtools.MeshExportModule.Q8; scalars=[("Temperature", Temp.values)])

  @test abs(minimum(Temp.values)-(-0.50124596))<1.0e-4
  @test abs(maximum(Temp.values)-(+0.50124596))<1.0e-4

  #println("Total time elapsed = ",time() - t0,"s")

  # Postprocessing
  # MeshExportModule.vtkexportmesh ("annulusmod.vtk", fes.conn, [geom.values Temp.values], MeshExportModule.Q4; scalars=Temp.values, scalars_name ="Temperature")
end

end
using mmmmannulus_Q4_example_algo
mmmmannulus_Q4_example_algo.test()

module mmmmmPoisson_FE_Q4_1
using FinEtools
using Base.Test
function test()
  # println("""
  #
  # Heat conduction example described by Amuthan A. Ramabathiran
  # http://www.codeproject.com/Articles/579983/Finite-Element-programming-in-Julia:
  # Unit square, with known temperature distribution along the boundary,
  # and uniform heat generation rate inside.  Mesh of regular four-node QUADRILATERALS,
  # in a grid of 1000 x 1000 edges (1M quads, 1M degrees of freedom).
  # Version: 05/29/2017
  # """
  # )
  t0 = time()

  A = 1.0
  thermal_conductivity = eye(2,2); # conductivity matrix
  function getsource!(forceout::FFltVec, XYZ::FFltMat, tangents::FFltMat, fe_label::FInt)
    forceout[1] = -6.0; #heat source
  end
  tempf(x) = (1.0 + x[:,1].^2 + 2*x[:,2].^2);
  N = 100;

  # println("Mesh generation")
  fens,fes = Q4block(A, A, N, N)

  geom = NodalField(fens.xyz)
  Temp = NodalField(zeros(size(fens.xyz,1),1))


  # println("Searching nodes  for BC")
  l1 = selectnode(fens; box=[0. 0. 0. A], inflate = 1.0/N/100.0)
  l2 = selectnode(fens; box=[A A 0. A], inflate = 1.0/N/100.0)
  l3 = selectnode(fens; box=[0. A 0. 0.], inflate = 1.0/N/100.0)
  l4 = selectnode(fens; box=[0. A A A], inflate = 1.0/N/100.0)
  List = vcat(l1, l2, l3, l4);
  setebc!(Temp, List, true, 1, tempf(geom.values[List,:])[:])
  applyebc!(Temp)

  numberdofs!(Temp)

  t1 = time()

  m = MatHeatDiff(thermal_conductivity)
  femm = FEMMHeatDiff(GeoD(fes, GaussRule(2, 2)), m)

  # println("Conductivity")
  K=conductivity(femm, geom, Temp)
  #Profile.print()

  # println("Nonzero EBC")
  F2 = nzebcloadsconductivity(femm, geom, Temp);
  # println("Internal heat generation")
  fi = ForceIntensity(FFlt, 1, getsource!);
  F1 = distribloads(femm, geom, Temp, fi, 3);

  # println("Factorization")
  K = cholfact(K)
  # println("Solution of the factorized system")
  U=  K\(F1+F2)
  scattersysvec!(Temp, U[:])


  # println("Total time elapsed = $(time() - t0) [s]")
  # println("Solution time elapsed = $(time() - t1) [s]")

  # using MeshExportModule

  # File =  "a.vtk"
  # MeshExportModule.vtkexportmesh (File, fes.conn, [geom.values Temp.values], MeshExportModule.Q4; scalars=Temp.values, scalars_name ="Temperature")

  Error = 0.0
  for k=1:size(fens.xyz,1)
    Error = Error+abs.(Temp.values[k,1]-tempf(reshape(fens.xyz[k,:], (1,2))))
  end
  # println("Error =$Error")
  @test Error[1]<1.e-5

  true
end
end
using mmmmmPoisson_FE_Q4_1
mmmmmPoisson_FE_Q4_1.test()

module mmmmmPoisson_FE_example_algo
using FinEtools
using Base.Test
function test()
  A= 1.0
  thermal_conductivity = eye(2,2); # conductivity matrix
  magn = -6.0; #heat source
  truetempf(x)=1.0 + x[1].^2 + 2.0*x[2].^2;
  N=20;

  # println("""
  #
  # Heat conduction example described by Amuthan A. Ramabathiran
  # http://www.codeproject.com/Articles/579983/Finite-Element-programming-in-Julia:
  # Unit square, with known temperature distribution along the boundary,
  # and uniform heat generation rate inside.  Mesh of regular TRIANGLES,
  # in a grid of $N x $N edges.
  # This version uses the FinEtools algorithm module.
  # """
  # )
  t0 = time()

  fens,fes =T3block(A, A, N, N)


  # Define boundary conditions
  l1 =selectnode(fens; box=[0. 0. 0. A], inflate = 1.0/N/100.0)
  l2 =selectnode(fens; box=[A A 0. A], inflate = 1.0/N/100.0)
  l3 =selectnode(fens; box=[0. A 0. 0.], inflate = 1.0/N/100.0)
  l4 =selectnode(fens; box=[0. A A A], inflate = 1.0/N/100.0)

  essential1 = FDataDict("node_list"=>vcat(l1, l2, l3, l4),
  "temperature"=>truetempf);
  material = MatHeatDiff(thermal_conductivity)
  femm = FEMMHeatDiff(GeoD(fes, TriRule(1)), material)
  region1 = FDataDict("femm"=>femm, "Q"=>magn)
  # Make model data
  modeldata= FDataDict("fens"=> fens,
  "regions"=>[region1],
  "essential_bcs"=>[essential1]);


  # Call the solver
  modeldata = FinEtools.AlgoHeatDiffModule.steadystate(modeldata)

  # println("Total time elapsed = ",time() - t0,"s")

  geom=modeldata["geom"]
  Temp=modeldata["temp"]
  femm=modeldata["regions"][1]["femm"]
  function errfh(loc,val)
    exact = truetempf(loc)
    return ((exact-val)^2)[1]
  end

  femm.geod.integration_rule = TriRule(6)
  E = integratefieldfunction(femm, geom, Temp, errfh, 0.0, m=3)
    # println("Error=$E")

    @test E<00.0025

  end
end
using mmmmmPoisson_FE_example_algo
mmmmmPoisson_FE_example_algo.test()

module mmmmmPoissonRm2
using FinEtools
using Base.Test
function test()
  # println("""
  # Heat conduction example described by Amuthan A. Ramabathiran
  # http://www.codeproject.com/Articles/579983/Finite-Element-programming-in-Julia:
  # Unit square, with known temperature distribution along the boundary,
  # and uniform heat generation rate inside.  Mesh of regular linear TRIANGLES,
  # in a grid of 1000 x 1000 edges (2M triangles, 1M degrees of freedom).
  # The material response is defined in a local coordinate system.
  # Version: 05/29/2017
  # """
  # )
  t0 = time()

  A = 1.0 # dimension of the domain (length of the side of the square)
  thermal_conductivity = eye(2,2); # conductivity matrix
  Q = -6.0; # internal heat generation rate
  function getsource!(forceout::FFltVec, XYZ::FFltMat, tangents::FFltMat, fe_label::FInt)
    forceout[1] = Q; #heat source
  end
  tempf(x) = (1.0 + x[:,1].^2 + 2*x[:,2].^2);#the exact distribution of temperature
  N = 100;# number of subdivisions along the sides of the square domain
  Rm=[-0.9917568452513019 -0.12813414805267656
  -0.12813414805267656 0.9917568452513019]
  Rm=[-0.8020689950104449 -0.5972313850116512
  -0.5972313850116512 0.8020689950104447]

  # println("Mesh generation")
  fens,fes =T3block(A, A, N, N)

  geom = NodalField(fens.xyz)
  Temp = NodalField(zeros(size(fens.xyz,1),1))

  # println("Searching nodes  for BC")
  l1 = selectnode(fens; box=[0. 0. 0. A], inflate = 1.0/N/100.0)
  l2 = selectnode(fens; box=[A A 0. A], inflate = 1.0/N/100.0)
  l3 = selectnode(fens; box=[0. A 0. 0.], inflate = 1.0/N/100.0)
  l4 = selectnode(fens; box=[0. A A A], inflate = 1.0/N/100.0)
  List = vcat(l1, l2, l3, l4)
  setebc!(Temp, List, true, 1, tempf(geom.values[List,:])[:])
  applyebc!(Temp)
  numberdofs!(Temp)

  t1 = time()

  material = MatHeatDiff(thermal_conductivity)

  femm = FEMMHeatDiff(GeoD(fes, TriRule(1), CSys(Rm)), material)


  # println("Conductivity")
  K = conductivity(femm, geom, Temp)
  # println("Nonzero EBC")
  F2 = nzebcloadsconductivity(femm, geom, Temp);
  # println("Internal heat generation")
  fi = ForceIntensity(FFlt[Q]);
  F1 = distribloads(femm, geom, Temp, fi, 3);

  # println("Factorization")
  K = cholfact(K)
  # println("Solution of the factorized system")
  U = K\(F1+F2)
  scattersysvec!(Temp,U[:])

  # println("Total time elapsed = $(time() - t0) [s]")
  # println("Solution time elapsed = $(time() - t1) [s]")

  Error= 0.0
  for k=1:size(fens.xyz,1)
    Error = Error+abs.(Temp.values[k,1]-tempf(reshape(fens.xyz[k,:], (1,2))))
  end
  # println("Error =$Error")
  @test Error[1]<1.e-4

end
end
using mmmmmPoissonRm2
mmmmmPoissonRm2.test()

module mmmmmmmmmNAFEMSm
using FinEtools
using Base.Test
function test()
  ## Two-dimensional heat transfer with convection: convergence study
  #

  ## Description
  #
  # Consider a plate of uniform thickness, measuring 0.6 m by 1.0 m. On one
  # short edge the temperature is fixed at 100 °C, and on one long edge the
  # plate is perfectly insulated so that the heat flux is zero through that
  # edge. The other two edges are losing heat via convection to an ambient
  # temperature of 0 °C. The thermal conductivity of the plate is 52.0 W/(m
  # .°K), and the convective heat transfer coefficient is 750 W/(m^2.°K).
  # There is no internal generation of heat. Calculate the temperature 0.2 m
  # along the un-insulated long side, measured from the intersection with the
  # fixed temperature side. The reference result is 18.25 °C.

  ##
  # The reference temperature at the point A  is 18.25 °C according to the
  # NAFEMS publication ( hich cites the book Carslaw, H.S. and J.C. Jaeger,
  # Conduction of Heat in Solids. 1959: Oxford University Press).

  ##
  # The present  tutorial will investigate the reference temperature  and it
  # will attempt to  estimate the  limit value more precisely using a
  # sequence of meshes and Richardson's extrapolation.

  ## Solution
  #

  # println("""
  # NAFEMS benchmark.
  # Two-dimensional heat transfer with convection: convergence study.
  # Solution with quadratic triangles.
  # Version: 05/29/2017
  # """
  # )

  kappa = [52. 0; 0 52.]*phun("W/(M*K)"); # conductivity matrix
  h = 750*phun("W/(M^2*K)");# surface heat transfer coefficient
  Width = 0.6*phun("M");# Geometrical dimensions
  Height = 1.0*phun("M");
  HeightA = 0.2*phun("M");
  Thickness = 0.1*phun("M");
  tolerance  = Width/1000;

  m = MatHeatDiff(kappa)

  modeldata = nothing
  resultsTempA = FFlt[]
  for nref = 1:5
    t0 = time()

    # The mesh is created from two triangles to begin with
    fens,fes = T3blockx([0.0, Width], [0.0, HeightA])
    fens2,fes2 = T3blockx([0.0, Width], [HeightA, Height])
    fens,newfes1,fes2 = mergemeshes(fens, fes, fens2, fes2, tolerance)
    fes = cat(newfes1,fes2)
    # Refine the mesh desired number of times
    for ref = 1:nref
      fens,fes = T3refine(fens,fes);
    end
    fens, fes = T3toT6(fens,fes);
    bfes = meshboundary(fes)

    # Define boundary conditions

    ##
    # The prescribed temperature is applied along edge 1 (the bottom
    # edge in Figure 1)..

    l1 = selectnode(fens; box=[0. Width 0. 0.], inflate=tolerance)
    essential1 = FDataDict("node_list"=>l1, "temperature"=> 100.);

    ##
    # The convection boundary condition is applied along the edges
    # 2,3,4. The elements along the boundary are quadratic line
    # elements L3. The order-four Gauss quadrature is sufficiently
    # accurate.
    l2 = selectelem(fens, bfes; box=[Width Width  0.0 Height], inflate =tolerance)
    l3 = selectelem(fens, bfes; box=[0.0 Width Height Height], inflate =tolerance)
    cfemm = FEMMHeatDiffSurf(GeoD(subset(bfes,vcat(l2,l3)),
      GaussRule(1, 3), Thickness), h)
    convection1 = FDataDict("femm"=>cfemm, "ambient_temperature"=>0.);

    # The interior
    femm = FEMMHeatDiff(GeoD(fes, TriRule(3), Thickness), m)
    region1 = FDataDict("femm"=>femm)

    # Make the model data
    modeldata = FDataDict("fens"=> fens,
    "regions"=>[region1],
    "essential_bcs"=>[essential1],
    "convection_bcs"=>[convection1]);

    # Call the solver
    modeldata = FinEtools.AlgoHeatDiffModule.steadystate(modeldata)

    # println("Total time elapsed = ",time() - t0,"s")

    l4 = selectnode(fens; box=[Width Width HeightA HeightA], inflate =tolerance)

    geom = modeldata["geom"]
    Temp = modeldata["temp"]

    ##
    # Collect the temperature  at the point A  [coordinates
    # (Width,HeightA)].
    push!(resultsTempA, Temp.values[l4][1]);

  end

  ##
  # These are the computed results for the temperature at point A:
  # println("$( resultsTempA  )")

  # Postprocessing
  geom = modeldata["geom"]
  Temp = modeldata["temp"]
  regions = modeldata["regions"]
  vtkexportmesh("T4NAFEMS--T6.vtk", regions[1]["femm"].geod.fes.conn,
  [geom.values Temp.values/100], FinEtools.MeshExportModule.T6;
  scalars=[("Temperature", Temp.values)])
  rm("T4NAFEMS--T6.vtk")
  vtkexportmesh("T4NAFEMS--T6--base.vtk", regions[1]["femm"].geod.fes.conn,
  [geom.values 0.0*Temp.values/100], FinEtools.MeshExportModule.T6)
  rm("T4NAFEMS--T6--base.vtk")
  # ##
  # # Richardson extrapolation is used to estimate the true solution from the
  # # results for the finest three meshes.
  #    [xestim, beta] = richextrapol(results(end-2:end),mesh_sizes(end-2:end));
  #     disp(['Estimated true solution for temperature at A: ' num2str(xestim) ' degrees'])

  # ##
  # # Plot the estimated true error.
  #    figure
  #     loglog(mesh_sizes,abs(results-xestim)/xestim,'bo-','linewidth',3)
  #     grid on
  #      xlabel('log(mesh size)')
  #     ylabel('log(|estimated temperature error|)')
  #     set_graphics_defaults

  # ##
  # # The estimated true error has  a slope of approximately 4 on the log-log
  # scale.
  # ##
  # # Plot the absolute values of the approximate error (differences  of
  # # successive solutions).
  #     figure
  #     loglog(mesh_sizes(2:end),abs(diff(results)),'bo-','linewidth',3)
  #     Thanksgrid on
  #     xlabel('log(mesh size)')
  #     ylabel('log(|approximate temperature error|)')
  #     set_graphics_defaults


  ## Discussion
  #
  ##
  # The last segment  of the approximate error curve is close to the slope of
  # the estimated true error. Nevertheless, it would have been more
  # reassuring if the  three successive approximate errors  were located more
  # closely on a straight line.

  ##
  # The use of uniform mesh-size meshes is sub optimal: it would be more
  # efficient to use graded meshes. The tutorial pub_T4NAFEMS_conv_graded
  # addresses use of graded meshes  in convergence studies.


  @test (norm(resultsTempA-[17.9028, 18.3323, 18.2965, 18.2619, 18.255])
  )<1.0e-3

end
end
using mmmmmmmmmNAFEMSm
mmmmmmmmmNAFEMSm.test()

module mmmmmmconvergence
using FinEtools
using Base.Test
function test()
  ## Two-dimensional heat transfer with convection: convergence study
  #

  ## Description
  #
  # Consider a plate of uniform thickness, measuring 0.6 m by 1.0 m. On one
  # short edge the temperature is fixed at 100 °C, and on one long edge the
  # plate is perfectly insulated so that the heat flux is zero through that
  # edge. The other two edges are losing heat via convection to an ambient
  # temperature of 0 °C. The thermal conductivity of the plate is 52.0 W/(m
  # .°K), and the convective heat transfer coefficient is 750 W/(m^2.°K).
  # There is no internal generation of heat. Calculate the temperature 0.2 m
  # along the un-insulated long side, measured from the intersection with the
  # fixed temperature side. The reference result is 18.25 °C.

  ##
  # The reference temperature at the point A  is 18.25 °C according to the
  # NAFEMS publication ( hich cites the book Carslaw, H.S. and J.C. Jaeger,
  # Conduction of Heat in Solids. 1959: Oxford University Press).

  ##
  # The present  tutorial will investigate the reference temperature  and it
  # will attempt to  estimate the  limit value more precisely using a
  # sequence of meshes and Richardson's extrapolation.

  ## Solution
  #

  # println("""
  # NAFEMS benchmark.
  # Two-dimensional heat transfer with convection: convergence study.
  # Solution with linear triangles.
  # Version: 05/29/2017
  # """
  # )

  kappa = [52. 0; 0 52.]*phun("W/(M*K)"); # conductivity matrix
  h = 750*phun("W/(M^2*K)");# surface heat transfer coefficient
  Width = 0.6*phun("M");# Geometrical dimensions
  Height = 1.0*phun("M");
  HeightA = 0.2*phun("M");
  Thickness = 0.1*phun("M");
  tolerance  = Width/1000;

  m = MatHeatDiff(kappa)

  modeldata = nothing
  resultsTempA = FFlt[]
  for nref = 1:5
    t0 = time()

    # The mesh is created from two triangles to begin with
    fens,fes = T3blockx([0.0, Width], [0.0, HeightA])
    fens2,fes2 = T3blockx([0.0, Width], [HeightA, Height])
    fens,newfes1,fes2 = mergemeshes(fens, fes, fens2, fes2, tolerance)
    fes = cat(newfes1,fes2)
    # Refine the mesh desired number of times
    for ref = 1:nref
      fens,fes = T3refine(fens,fes);
    end
    bfes = meshboundary(fes)

    # Define boundary conditions

    ##
    # The prescribed temperature is applied along edge 1 (the bottom
    # edge in Figure 1)..

    l1 = selectnode(fens; box=[0. Width 0. 0.], inflate=tolerance)
    essential1 = FDataDict("node_list"=>l1, "temperature"=> 100.);

    ##
    # The convection boundary condition is applied along the edges
    # 2,3,4. The elements along the boundary are quadratic line
    # elements L3. The order-four Gauss quadrature is sufficiently
    # accurate.
    l2 = selectelem(fens, bfes; box=[Width Width  0.0 Height], inflate =tolerance)
    l3 = selectelem(fens, bfes; box=[0.0 Width Height Height], inflate =tolerance)
    cfemm = FEMMHeatDiffSurf(GeoD(subset(bfes,vcat(l2,l3)),
      GaussRule(1, 3), Thickness), h)
    convection1 = FDataDict("femm"=>cfemm, "ambient_temperature"=>0.);

    # The interior
    femm = FEMMHeatDiff(GeoD(fes, TriRule(3), Thickness), m)
    region1 = FDataDict("femm"=>femm)

    # Make the model data
    modeldata = FDataDict("fens"=> fens,
    "regions"=>[region1],
    "essential_bcs"=>[essential1],
    "convection_bcs"=>[convection1]);

    # Call the solver
    modeldata = FinEtools.AlgoHeatDiffModule.steadystate(modeldata)

    # println("Total time elapsed = ",time() - t0,"s")

    l4 = selectnode(fens; box=[Width Width HeightA HeightA], inflate =tolerance)

    geom = modeldata["geom"]
    Temp = modeldata["temp"]

    ##
    # Collect the temperature  at the point A  [coordinates
    # (Width,HeightA)].
    push!(resultsTempA, Temp.values[l4][1]);

  end

  ##
  # These are the computed results for the temperature at point A:
  # println("$( resultsTempA  )")

  # Postprocessing
  geom = modeldata["geom"]
  Temp = modeldata["temp"]
  regions = modeldata["regions"]
  vtkexportmesh("T4NAFEMS--T3.vtk", regions[1]["femm"].geod.fes.conn,
  [geom.values Temp.values/100], FinEtools.MeshExportModule.T3;
  scalars=[("Temperature", Temp.values)])
  rm("T4NAFEMS--T3.vtk")
  vtkexportmesh("T4NAFEMS--T3--base.vtk", regions[1]["femm"].geod.fes.conn,
  [geom.values 0.0*Temp.values/100], FinEtools.MeshExportModule.T3)
  rm("T4NAFEMS--T3--base.vtk")
  # ##
  # # Richardson extrapolation is used to estimate the true solution from the
  # # results for the finest three meshes.
  #    [xestim, beta] = richextrapol(results(end-2:end),mesh_sizes(end-2:end));
  #     disp(['Estimated true solution for temperature at A: ' num2str(xestim) ' degrees'])

  # ##
  # # Plot the estimated true error.
  #    figure
  #     loglog(mesh_sizes,abs(results-xestim)/xestim,'bo-','linewidth',3)
  #     grid on
  #      xlabel('log(mesh size)')
  #     ylabel('log(|estimated temperature error|)')
  #     set_graphics_defaults

  # ##
  # # The estimated true error has  a slope of approximately 4 on the log-log
  # scale.
  # ##
  # # Plot the absolute values of the approximate error (differences  of
  # # successive solutions).
  #     figure
  #     loglog(mesh_sizes(2:end),abs(diff(results)),'bo-','linewidth',3)
  #     Thanksgrid on
  #     xlabel('log(mesh size)')
  #     ylabel('log(|approximate temperature error|)')
  #     set_graphics_defaults


  ## Discussion
  #
  ##
  # The last segment  of the approximate error curve is close to the slope of
  # the estimated true error. Nevertheless, it would have been more
  # reassuring if the  three successive approximate errors  were located more
  # closely on a straight line.

  ##
  # The use of uniform mesh-size meshes is sub optimal: it would be more
  # efficient to use graded meshes. The tutorial pub_T4NAFEMS_conv_graded
  # addresses use of graded meshes  in convergence studies.

  @test (norm(resultsTempA- [22.7872, 19.1813, 18.516, 18.3816, 18.3064])       )<1.0e-3

end
end
using mmmmmmconvergence
mmmmmmconvergence.test()