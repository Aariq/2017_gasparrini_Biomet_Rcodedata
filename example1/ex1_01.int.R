################################################################################
# Updated version of the R code for the analysis in:
#
#   "A penalized framework for distributed lag non-linear models"
#   Biometrics, 2017
#   Antonio Gasparrini, Fabian Scheipl, Ben Amstrong, and Michael G. Kenward
#   http://www.ag-myresearch.com/2017_gasparrini_biomet.html
#
# Update: 15 Jan 2017
# * an up-to-date version of this code is available at:
#   https://github.com/gasparrini/2017_gasparrini_biomet_Rcodedata
################################################################################

################################################################################
# FIRST EXAMPLE
# LOAD THE DATA AND RUN THE MODELS (INTERNAL METHOD)
################################################################################

# LOAD PACKAGES AND FUNCTIONS
library(dlnm) ; library(mgcv) ; library(splines) ; library(tsModel) ; library(here)

# LOAD DATA
london <- read.csv(here("example1","london.csv"))

################################################################################
# GLM WITH KNOTS SPECIFIED A PRIORI (GASPARRINI BMCmrm 2014)

# DEFINE THE CROSS-BASIS
vk <- equalknots(london$tmean,nk=2)
lk <- logknots(25,nk=3)
cbglm1 <- crossbasis(
  london$tmean,
  lag=25,
  argvar=list(fun="bs",degree=2,knots=vk), 
  arglag=list(knots=lk))
summary(cbglm1)

# RUN THE MODEL AND PREDICT
library(splines)
glm1 <- glm(death~cbglm1+ns(time,10*14)+dow,family=quasipoisson(),london)
pred3dglm1 <- crosspred(cbglm1,glm1,at=-3:29,cen=20)
predslglm1 <- crosspred(cbglm1,glm1,by=0.2,bylag=0.2,cen=20)

# PLOTS
plot(pred3dglm1,xlab="Temperature (C)",zlab="RR",zlim=c(0.88,1.45),xlim=c(-5,30),
  ltheta=170,phi=35,lphi=30,main="Original GLM")
plot(predslglm1,"overall",ylab="RR",xlab="Temperature (C)",xlim=c(-5,30),
  ylim=c(0.5,3.5),lwd=1.5,main="Original GLM")
plot(predslglm1,var=29,xlab="Lag (days)",ylab="RR",ylim=c(0.9,1.4),lwd=1.5,
  main="Original GLM")

################################################################################
# GLM WITH AIC-BASED KNOT SELECTION

# Q-AIC FUNCTION
fqaic <- function(model) {
  loglik <- sum(dpois(model$y,model$fitted.values,log=TRUE))
  phi <- summary(model)$dispersion
  qaic <- -2*loglik + 2*summary(model)$df[3]*phi
  return(qaic)
}

# KNOTS GRID
grid <- as.matrix(expand.grid(var=1:8,lag=1:8))

# SEARCH (TAKES ~40sec IN A 2.4 GHz PC)
system.time({
aicval <- sapply(seq(nrow(grid)), function(i) {
  vk <- equalknots(london$tmean,nk=grid[i,1])
  lk <- logknots(25,nk=grid[i,2])
  cb <- crossbasis(london$tmean,lag=25,argvar=list(fun="bs",degree=2,knots=vk),
    arglag=list(knots=lk))
  m <- glm(death~cb+ns(time,10*14)+dow,family=quasipoisson(),london)
  return(fqaic(m))
})
})

# BEST FITTING MODEL
(best <- grid[which.min(aicval),])
plot(aicval,col=2,pch=19)

# DEFINE THE CROSS-BASIS
vk <- equalknots(london$tmean,nk=best[1])
lk <- logknots(25,nk=best[2])
cbglm2 <- crossbasis(london$tmean,lag=25,argvar=list(fun="bs",degree=2,
  knots=vk),arglag=list(knots=lk))
summary(cbglm2)

# RUN THE MODEL AND PREDICT
glm2 <- glm(death~cbglm2+ns(time,10*14)+dow,family=quasipoisson(),london)
pred3dglm2 <- crosspred(cbglm2,glm2,at=-3:29,cen=20)
predslglm2 <- crosspred(cbglm2,glm2,by=0.2,bylag=0.2,cen=20)

# PLOTS
plot(pred3dglm2,xlab="Temperature (C)",zlab="RR",zlim=c(0.88,1.45),xlim=c(-5,30),
  ltheta=170,phi=35,lphi=30,main="GLM with AIC-based knot selection")
plot(predslglm2,"overall",ylab="RR",xlab="Temperature (C)",xlim=c(-5,30),
  ylim=c(0.5,3.5),lwd=1.5,main="GLM with AIC-based knot selection")
plot(predslglm2,var=29,xlab="Lag (days)",ylab="RR",ylim=c(0.9,1.4),lwd=1.5,
  main="GLM with AIC-based knot selection")

################################################################################
# GAM WITH DEFAULT PENALTIES

# DEFINE MATRICES TO BE INCLUDED AS TERMS IN THE SMOOTHER
Q <- Lag(london$tmean, 0:25) #temperature data, lagged
L <- matrix(0:25,nrow(Q),ncol(Q),byrow=TRUE) #matrix of 0-25

# RUN THE GAM MODEL AND PREDICT (TAKES ~17sec IN A 2.4 GHz PC)
# SET 'cb' SMOOTHER WITH DIMENSION 10 FOR EACH SPACE (MINUS CONSTRAINTS)
system.time({
gam1 <- gam(death ~ s(Q, L, bs="cb", k=10) + ns(time, 10*14) + dow,
            family=quasipoisson(),
            london,
            method='REML')
})
pred3dgam1 <- crosspred("Q", gam1, at = -3:29, cen = 20)
predslgam1 <- crosspred("Q", gam1, by=0.2, bylag=0.2, cen=20)

# CHECK CONVERGENCE, SMOOTHING PARAMETERS AND EDF
gam1$converged
gam1$sp
summary(gam1)$edf

# PLOTS
plot(pred3dgam1,xlab="Temperature (C)",zlab="RR",zlim=c(0.88,1.45),xlim=c(-5,30),
 ltheta=170,phi=35,lphi=30,main="GAM with default penalties")
plot(predslgam1,"overall",ylab="RR",xlab="Temperature (C)",xlim=c(-5,30),
  ylim=c(0.5,3.5),lwd=1.5,main="GAM with default penalties")
plot(predslgam1,var=29,xlab="Lag (days)",ylab="RR",ylim=c(0.9,1.4),lwd=1.5,
  main="GAM with default penalties")

################################################################################
# GAM WITH DOUBLY VARYING PENALTY ON THE LAG

# DEFINE THE DOUBLY VARYING PENALTY MATRICES
# VARYING DIFFERENCE PENALTY APPLIED TO LAGS (EQ. 8b)
C <- do.call('onebasis',c(list(x=0:25,fun="ps",df=10,intercept=T)))
D <- diff(diag(25+1),diff=2)
P <- diag((seq(0,25-2))^2)
Slag1 <- t(C) %*% t(D) %*% P %*% D %*% C

# VARYING RIDGE PENALTY APPLIED TO COEFFICIENTS (Eq. 7a)
Slag2 <- diag(rep(0:1,c(6,4)))

# RUN THE GAM MODEL AND PREDICT (TAKES ~15sec IN A 2.4 GHz PC)
# PS: EXCLUDE THE DEFAULT PENALTY FROM THE LAG-RESPONSE FUNCTION WITH fx=T
# ADD ADDITIONAL PENALTY MATRICES FOR THE LAG SPACE IN addSlag OBJECT IN xt
xt <- list(addSlag=list(Slag1,Slag2))
system.time({
  
gam2 <- gam(death ~ s(Q, L, #two dimensions effect of temp and effect of lag
                      bs="cs", k=10,
                      fx=c(F,T), #remove default penalty from lag
                      xt = xt #add aditional penalties that you've created yourself to lag
                      ) + ns(time, 10*14) + dow,
  family=quasipoisson(),
  london,
  method='REML')
})
pred3dgam2 <- crosspred("Q",gam2,at=-3:29,cen=20)
predslgam2 <- crosspred("Q",gam2,by=0.2,bylag=0.2,cen=20)

# CHECK CONVERGENCE, SMOOTHING PARAMETERS AND EDF
gam2$converged
gam2$sp
summary(gam2)$edf

# PLOTS
plot(pred3dgam2,xlab="Temperature (C)",zlab="RR",zlim=c(0.88,1.45),xlim=c(-5,30),
 ltheta=170,phi=35,lphi=30,main="GAM with doubly varying penalties")
plot(predslgam2,"overall",ylab="RR",xlab="Temperature (C)",xlim=c(-5,30),
  ylim=c(0.5,3.5),lwd=1.5,main="GAM with doubly varying penalties")
plot(predslgam2,var=29,xlab="Lag (days)",ylab="RR",ylim=c(0.9,1.4),lwd=1.5,
  main="GAM with doubly varying penalties")

################################################################################
# GAM WITH ONE DIMENSION UNPENALIZED BY USING PARAMETRIC FUNCTIONS

# RUN THE GAM MODEL AND PREDICT (TAKES ~8sec IN A 2.4 GHz PC)
# NB: DOUBLE THRESHOLD AS EXPOSURE-RESPONSE DEFINED IN xt
thr <- dlnm:::thr
xt=list(addSlag=list(Slag1,Slag2),argvar=list(fun="thr",thr=c(17,21)))
system.time({
gam3 <- gam(death~s(Q,L,bs="cs",k=10,fx=c(F,T),xt=xt)+ns(time, 10*14)+dow,
  family=quasipoisson(),london, method='REML')
})
pred3dgam3 <- crosspred("Q",gam3,at=-3:29)
predslgam3 <- crosspred("Q",gam3,by=0.2,bylag=0.2)

# CHECK CONVERGENCE, SMOOTHING PARAMETERS AND EDF
gam3$converged
gam3$sp
summary(gam3)$edf

# PLOTS
plot(pred3dgam3,xlab="Temperature (C)",zlab="RR",zlim=c(0.88,1.45),xlim=c(-5,30),
  ltheta=170,phi=35,lphi=30,main="Mix of penalized and unpenalized")
plot(predslgam3,"overall",ylab="RR",xlab="Temperature (C)",xlim=c(-5,30),
  ylim=c(0.8,2.2),lwd=1.5,main="Mix of penalized and unpenalized")
plot(predslgam3,var=29,xlab="Lag (days)",ylab="RR",ylim=c(0.9,1.4),lwd=1.5,
  main="Mix of penalized and unpenalized")

#
