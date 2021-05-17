## ----global_options, include=FALSE--------------------------------------------
knitr::opts_chunk$set(fig.width=6, fig.height=5.5, fig.path='Figs/', fig.show='hold',
                      warning=FALSE, message=FALSE)

## ----load_libraries, message=FALSE, warning=FALSE-----------------------------
require(Mcomp)
require(legion)

## ----form_the_vector, message=FALSE, warning=FALSE----------------------------
Y <- cbind(M3$N2570$x,M3$N2571$x);

## ----vets_basic---------------------------------------------------------------
vetsModel <- vets(Y, "MMdM", h=18, holdout=TRUE, silent=FALSE)

## ----autovets-----------------------------------------------------------------
vetsModel <- auto.vets(Y, "PPP", h=18, holdout=TRUE, silent=FALSE)

## -----------------------------------------------------------------------------
oldpar <- par(mfcol=c(2,1))
plot(vetsModel,1)
plot(vetsModel,7)
par(oldpar)

## -----------------------------------------------------------------------------
modelType(vetsModel)
modelType(vetsModel,pic=TRUE)

## ----eval=FALSE---------------------------------------------------------------
#  actuals(vetsModel)
#  fitted(vetsModel)
#  residuals(vetsModel)

## -----------------------------------------------------------------------------
vetsForecast <- forecast(vetsModel, h=18, interval="prediction")
oldpar <- par(mfcol=c(2,1))
plot(vetsForecast)
par(oldpar)

