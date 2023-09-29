using Quadmath

function filter!(u, params, SD::NSD_2D)
  
  u2uaux!(@view(params.uaux[:,:]), u, params.neqs, params.mesh.npoin)

  fy_t = transpose(params.fy)
  ## Subtract background velocity
  #qv = copy(q)
  params.uaux[:,2:4] .= params.uaux[:,2:4] .- params.qe[:,2:4]
  q_t = zeros(Float64,params.neqs,params.mesh.ngl,params.mesh.ngl)
  fqf = zeros(Float64,params.neqs,params.mesh.ngl,params.mesh.ngl)
  ## store Dimension of MxM object
  b = zeros(params.mesh.nelem, params.mesh.ngl, params.mesh.ngl, params.neqs) 
  inode = zeros(Int64,params.mesh.ngl*params.mesh.ngl)
  ndim = params.neqs

  ## Loop through the elements

  for e=1:params.mesh.nelem
    for j=1:params.mesh.ngl
      for i=1:params.mesh.ngl
        ip = params.mesh.connijk[e,i,j]
        for m =1:params.neqs
          q_t[m,i,j] = params.uaux[ip,m]
        end
      end
    end
  
  ### Construct local derivatives for prognostic variables
  
    for m=1:params.neqs
    
    ##KSI Derivative

      q_ti = params.fx * q_t[m,:,:] 

    ## ETA Derivative
 
      q_tij = q_ti * fy_t

      fqf[m,:,:] = q_tij
    end
    
  ## Do Numerical Integration

    for j=1:params.mesh.ngl
      for i=1:params.mesh.ngl
        ip = params.mesh.connijk[e,i,j]
        for m=1:params.neqs
          b[e,i,j,m] = b[e,i,j,m] + fqf[m,i,j] * params.ω[i]*params.ω[j]*params.metrics.Je[e,i,j]
        end
      end
    end
  end
  
  B         = zeros(Float64, params.mesh.npoin, params.neqs)
  DSS_rhs!(@view(B[:,:]), @view(b[:,:,:,:]), params.mesh, params.mesh.nelem, params.mesh.ngl, params.neqs, SD)
  
  for ieq=1:params.neqs
        divide_by_mass_matrix!(@view(B[:,ieq]), params.vaux, params.Minv, params.neqs, params.mesh.npoin)
  end
  #=if (params.laguerre)
      
      fy_t_lag = transpose(params.fy_lag)
      @info fy_t_lag
      @info fx
      q_t_lag = zeros(Float64,params.neqs,params.mesh.ngl,params.mesh.ngr)
      fqf_lag = zeros(Float64,params.neqs,params.mesh.ngl,params.mesh.ngr)
      ## store Dimension of MxM object
      b_lag = zeros(params.mesh.nelem, params.mesh.ngl, params.mesh.ngr, params.neqs)
      inode_lag = zeros(Int64,params.mesh.ngl*params.mesh.ngr)
      ndim = params.neqs

  ## Loop through the elements
  
      for e=1:params.mesh.nelem_semi_inf
        for j=1:params.mesh.ngr
          for i=1:params.mesh.ngl
            ip = params.mesh.connijk_lag[e,i,j]
            for m =1:params.neqs
              q_t_lag[m,i,j] = params.uaux[ip,m]
            end
          end
        end
 
  ### Construct local derivatives for prognostic variables
 
        for m=1:params.neqs
 
    ##KSI Derivative
          q_ti_lag = params.fx * q_t_lag[m,:,:]

    ## ETA Derivative
          
          q_tij_lag = q_ti_lag * fy_t_lag
          fqf_lag[m,:,:] = q_tij_lag
        end
  
  ## Do Numerical Integration

        for j=1:params.mesh.ngr
          for i=1:params.mesh.ngl
            ip = params.mesh.connijk_lag[e,i,j]
            for m=1:params.neqs
              b_lag[e,i,j,m] = b_lag[e,i,j,m] + fqf_lag[m,i,j] * params.ω[i]*params.ω_lag[j]*params.metrics_lag.Je[e,i,j]
            end
          end
        end
      end
      @info maximum(b_lag), minimum(b_lag)
      B_lag = zeros(Float64, params.mesh.npoin, params.neqs)
      DSS_rhs_laguerre!(@view(B_lag[:,:]), @view(b_lag[:,:,:,:]), params.mesh, params.mesh.nelem, params.mesh.ngl, params.neqs, SD) 
      @info maximum(B_lag), minimum(B_lag)
      for ieq=1:params.neqs
            divide_by_mass_matrix!(@view(B_lag[:,ieq]), params.vaux, params.Minv, params.neqs, params.mesh.npoin)
      end
      @info maximum(B), minimum(B), maximum(B_lag), minimum(B_lag)
      B .= @views(B .+ B_lag)      
  end=#
  
  params.uaux .= B
  params.uaux[:,2:4] .= params.uaux[:,2:4] .+ params.qe[:,2:4]

  uaux2u!(u, @view(params.uaux[:,:]), params.neqs, params.mesh.npoin)  
end

function init_filter(nop,xgl,mu_x)

  f = zeros(Float64,nop+1,nop+1)
  weight = ones(Float64,nop+1)
  exp_alpha = 36
  exp_order = 12
  quad_alpha = 1.0
  quad_order = (nop+1)/3
  erf_alpha = 0.0
  erf_order = 12
  Legendre = St_Legendre{Float128}(0.0,0.0,0.0,0.0)  
  leg = zeros(Float128,nop+1,nop+1)
  ## Legendre Polynomial matrix
  for i = 1:nop+1
    ξ = xgl[i]
    for j = 1:nop+1
      jj = j - 1
      LegendreAndDerivativeAndQ!(Legendre, jj, ξ)      
      leg[i,j] = Legendre.legendre
    end
  end
  
  ### Heirarchical Modal Legendre Basis
  leg2 = zeros(Float128,nop+1,nop+1)
  leg2 .= leg
  for i=1:nop+1
    ξ = xgl[i]
    leg2[i,1] = 0.5*(1 - ξ)
    if (nop +1 > 1)
      leg2[i,2] = 0.5*(1 + ξ)
      for j=3:nop+1
        leg2[i,j] = leg[i,j] - leg[i,j-2]
      end
    end
  end

  #### Compute Inverse Matrix
  leg_inv = zeros(Float128,nop+1,nop+1)
  leg_inv .= leg2
  ierr = 0
  gaujordf!(leg_inv,nop+1,ierr)
  if (ierr != 0)
    @info "Error in GAUJORDF in FILTER INIT"
    @info "ierr", ierr
    exit
  end
  
  ## Compute Boyd-Vandeven (ERF-LOG) Transfer function
  filter_type = "erf"
  if (filter_type == "erf")   
    @info "erf filtering on"
    for k=1:nop+1
      # Boyd filter
      weight[k] = vandeven_modal(k,nop+1,erf_order)
    end
  elseif (filter_type == "quad")
    @info "quadratic filtering on"
    mode_filter = floor(quad_order)   
    k0 = Int64(nop+1 - mode_filter)
    xmode2 = mode_filter*mode_filter
    weight .= 1
    for k=k0+1:nop+1
      amp = quad_alpha*(k-k0)*(k-k0)/(xmode2)
      weight[k] = 1.0 - amp
    end
  elseif (filter_type == "exp")
    @info "exponential filtering on"
    for k=1:nop+1
      weight[k] = exp(-exp_alpha*(Float64(k-1)/nop)^exp_order)
    end
  end 
  ## Construct 1D Filter matrix
  for i=1:nop+1
    for j=1:nop+1
      sum = 0
      for k=1:nop+1
        sum = sum + leg2[i,k] * weight[k] * leg_inv[k,j]
      end
      f[i,j] = mu_x * sum
    end
    f[i,i] = f[i,i] + (1.0 - mu_x)
  end
  return f
end
function gaujordf!(a,n,ierr)
  
  ## Initialize
  ierr = 0
  eps = 1.0e-9
  ipiv = zeros(Int64,n)
  indr = zeros(Int64,n)
  indc = zeros(Int64,n)  

  for i=1:n
    big = 0

    ## Pivot Search
    irow = -1
    icol = -1
  
    for j=1:n
      if (ipiv[j] != 1)
        for k = 1:n
          if (ipiv[k] == 0)
            if (abs(a[j,k]) >= big)
              big = abs(a[j,k])
              irow = j
              icol = k
            end
          elseif (ipiv[k] > 1)
            ierr = -ipiv
            return nothing
          end
        end
      end
    end
   
    ipiv[icol] = ipiv[icol] + 1

    ## Swap rows
    
    if (irow != icol)
      for l=1:n
        dum = a[irow,l]
        a[irow,l] = a[icol,l]
        a[icol,l] = dum
      end
    end
    indr[i] = irow
    indc[i] = icol
    if (abs(a[icol,icol]) < eps)
      @info "small Gauss Jordan Pivot:", icol, a[icol,icol]
      ierr = icol
      return nothing
    end
    piv = 1.0/a[icol,icol]
    a[icol,icol] = 1.0
    for l=1:n
      a[icol,l] = a[icol,l]*piv
    end
    
    for ll=1:n
      if (ll != icol)
        dum = a[ll,icol]
        a[ll,icol] = 0.0
        for l=1:n
          a[ll,l] = a[ll,l] - a[icol,l]*dum
        end
      end
    end
  end
    
  ## Unscramble Matrix
  
  for l=n:-1:1
    if (indr[l] != indc[l])
      for k = 1:n
        dum = a[k,indr[l]]
        a[k,indr[l]] = a[k,indc[l]]
        a[k,indc[l]] = dum
      end
    end
  end

end 
    
function vandeven_modal(kk,ngl,p)
  
  ## Constants - ERF
  pe=0.3275911
  a1=0.254829592
  a2=-0.284496736
  a3=1.421413741
  a4=-1.453152027
  a5=1.061405429

  ## Constants - Vandeven
  n=ngl-1
  k=kk-1
  i=2*n/3
  eps=1.0e-10

  if (k <= i)
    x = 0
    return 1
  elseif (k > i && k < n)
    x = Float64(k-i)/Float64(n - i)
    omega = abs(x) - 0.5
    xlog = log(1.0-4.0*omega^2)
    c = 4.0 * omega^2
    diff = abs(x-0.5)
    if (diff < eps)
      square_root = 1
    else
      square_root = sqrt(-xlog/c)
    end
    
    z = 2.0 * sqrt(p) * omega * square_root
    zc = abs(z)
    
    ## ERF
    t = 1.0/(1.0 + pe * zc)
    c = 1.0 - (a1 * t + a2*t^2 + a3*t^3 + a4*t^4 + a5*t^5) * exp(-zc*zc)
    if (zc < eps)
      c = 0.0
    else
      c = c*z/zc
    end
    return 0.5 * (1.0 - c)
  
  elseif(k == n)
    x=1
    return 0.0
  else
    @info "problem in Vandeven_modal"
    exit
  end
end