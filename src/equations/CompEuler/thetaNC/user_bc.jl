"""
    qibdy is an Array{Floats} of size `nvars`

    src/equations/EQUATIONS_NAME/user_bc.jl contains a set of user-defined boundary conditions functions
    that can be modified as needed.

    The function defined in src/equations/EQUATIONS_NAME/user_bc.jl 
    are called by the b.c. functions defined in src/kernel/custom_bcs.jl
    within a boundary-edge loop that detects the "tag" string defined in the user-generated *.msh file.

    For example:
    If some domain boundaries of gmsh file mymesh.msh are tagged as "inflow" and "no_slip", then the user
    creating the functions in user_bc.jl must define the behavior of the unknown or its derivatives
    on those boundaries.

    ```math
    if (tag === "inflow")
        qibdy[1] = 3.0
    elseif (tag === "fix_temperature")
        qibdy[2] = 300.0
    end
    return qibdy
    ```
    where  `qibdy[i=1:nvar]` is the value unknown `i`
    
"""
function user_bc_dirichlet!(qbdy, x, y, t, tag::String, inputs)    
    
    #fill!(flags, zero(Float64))
    if ( x <= -4990.0 || x >= 4990.0)
        qbdy[2] = 0.0
    end
    if (y <= 10.0 || y >= 9990.0)
        qbdy[3] = 0.0
    end
    if ((x >= 4990.0 || x <= -4990.0) && (y >= 9990.0 || y <= 10.0))
        qbdy[2] = 0.0
        qbdy[3] = 0.0
    end
    
end

function user_bc_neumann(q::AbstractArray, gradq::AbstractArray, x::AbstractFloat, y::AbstractFloat, t::AbstractFloat, tag::String, inputs::Dict)
    fill!(flux, zero(Float64))
    return flux
end

function user_bc_neumann(q::AbstractArray, gradq::AbstractArray, x::AbstractFloat, t::AbstractFloat, inputs::Dict)
    fill!(flux, zero(Float64))
    return flux
end
