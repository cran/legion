#' Occurrence part of Vector State Space
#'
#' Function calculates the probability for the occurrence part of vector state space model.
#' This is needed in order to forecast intermittent demand using other functions.
#'
#' The function estimates probability of demand occurrence, using one of the VES
#' state-space models.
#'
#' @template ssAuthor
#' @template vssKeywords
#'
#' @param data The matrix with data, where series are in columns and
#' observations are in rows.
#' @param occurrence Type of method used in probability estimation. Can be
#' \code{"none"} - none, \code{"fixed"} - constant probability or
#' \code{"logistic"} - probability based on logit model.
#' @param ic Information criteria to use in case of model selection.
#' @param h Forecast horizon.
#' @param holdout If \code{TRUE}, holdout sample of size \code{h} is taken from
#' the end of the data.
#' @param probability Type of probability assumed in the model. If
#' \code{"dependent"}, then it is assumed that occurrence of one variable is
#' connected with the occurrence with another one. In case of \code{"independent"}
#' the occurrence of the variables is assumed to happen independent of each
#' other.
#' @param model Type of ETS model used for the estimation. Normally this should
#' be either \code{"ANN"} or \code{"MNN"}. If you assume that there are some
#' tendencies in occurrence, then you can use more complicated models. Model
#' selection is not yet available.
#' @param persistence Persistence matrix type. If \code{NULL}, then it is estimated.
#' See \link[legion]{ves} for the details.
#' @param transition Transition matrix type. If \code{NULL}, then it is estimated.
#' See \link[legion]{ves} for the details.
#' @param phi Damping parameter type. If \code{NULL}, then it is estimated.
#' See \link[legion]{ves} for the details.
#' @param initial Initial vector type. If \code{NULL}, then it is estimated.
#' See \link[legion]{ves} for the details.
#' @param initialSeason Type of the initial vector of seasonal components.
#' If \code{NULL}, then it is estimated. See \link[legion]{ves} for the details.
#' @param xreg Vector of matrix of exogenous variables, explaining some parts
#' of occurrence variable (probability).
#' @param ... Other parameters. This is not needed for now.
#' @return The object of class "oves" is returned. It contains following list of
#' values:
#'
#' \itemize{
#' \item \code{model} - the type of the estimated ETS model;
#' \item \code{fitted} - fitted values of the constructed model;
#' \item \code{forecast} - forecast for \code{h} observations ahead;
#' \item \code{states} - values of states (currently level only);
#' \item \code{variance} - conditional variance of the forecast;
#' \item \code{logLik} - likelihood value for the model
#' \item \code{nParam} - number of parameters used in the model;
#' \item \code{residuals} - residuals of the model;
#' \item \code{data} - actual values of probabilities (zeros and ones).
#' \item \code{persistence} - the vector of smoothing parameters;
#' \item \code{initial} - initial values of the state vector;
#' \item \code{initialSeason} - the matrix of initials seasonal states;
#' \item \code{occurrence} - type of occurrence model used;
#' \item \code{probability} - type of probability used;
#' \item \code{issModel} - intermittent state-space model used for
#' calculations. Useful only in the case of \code{occurrence="l"} and
#' \code{probability="d"}.
#' }
#' @seealso \code{\link[smooth]{oes}, \link[legion]{ves}}
#' @examples
#'
#' Y <- cbind(c(rpois(25,0.1),rpois(25,0.5),rpois(25,1),rpois(25,5)),
#'            c(rpois(25,0.1),rpois(25,0.5),rpois(25,1),rpois(25,5)))
#'
#' oves(Y, occurrence="l")
#' oves(Y, occurrence="l", probability="i")
#'
#' @importFrom smooth oes
#' @export oves
oves <- function(data, occurrence=c("logistic","none","fixed"),
                 ic=c("AICc","AIC","BIC","BICc"), h=10, holdout=FALSE,
                 probability=c("dependent","independent"),
                 model="ANN", persistence=NULL, transition=NULL, phi=NULL,
                 initial=NULL, initialSeason=NULL, xreg=NULL, ...){
# Function returns occurrence State-Space model
# probability="i" - assume that ot[,1] is independent from ot[,2], but has similar dynamics;
# probability="d" - assume that ot[,1] and ot[,2] are dependent, so that sum(P)=1;

    occurrence <- substring(occurrence[1],1,1);
    if(all(occurrence!=c("n","f","l"))){
        warning(paste0("Unknown value of occurrence provided: '",occurrence,"'."));
        occurrence <- "f";
    }

    ic <- ic[1];

    Etype <- substr(model,1,1);
    Ttype <- substr(model,2,2);
    Stype <- substr(model,nchar(model),nchar(model));
    if(nchar(model)==4){
        damped <- "d";
    }
    else{
        damped <- NULL;
    }

    if(is.null(probability)){
        warning("probability value is not specified. Switching to 'independent'.");
        probability <- "i";
    }
    else{
        probability <- substr(probability[1],1,1);
    }

    # There's no difference in probabilities when occurrence=="f" or "n". So use simpler one.
    if((occurrence!="l") & probability=="d"){
        probability <- "i";
    }

    if(is.null(persistence)){
        if(probability=="d"){
            persistence <- "c";
        }
    }
    if(is.null(transition)){
        if(probability=="d"){
            transition <- "c";
        }
    }
    if(is.null(phi)){
        if(probability=="d"){
            phi <- "c";
        }
    }
    if(!is.null(initial)){
        # If a numeric is provided in initial, check it
        if(is.numeric(initial)){
            if((probability=="i" & length(initial)!=nSeries) |
               (probability=="d" & length(initial)!=2^nSeries)){
                warning("Wrong length of the initial vector");
                initial <- NULL;
                initialIsNumeric <- FALSE;
            }
            initialIsNumeric <- TRUE;
        }
        else{
            initialIsNumeric <- FALSE;
        }
    }
    else{
        if(probability=="d"){
            initial <- "i";
        }
        initialIsNumeric <- FALSE;
    }
    if(is.null(initialSeason)){
        if(probability=="d"){
            initialSeason <- "c";
        }
    }

    if(is.data.frame(data)){
        data <- as.matrix(data);
    }

    # Number of series in the matrix
    nSeries <- ncol(data);

    if(is.null(nSeries)){
        stop("The provided data is not a matrix! Use oes() function instead!", call.=FALSE);
    }
    if(ncol(data)==1){
        stop("The provided data contains only one column. Use oes() function instead!", call.=FALSE);
    }
    # Check the data for NAs
    if(any(is.na(data))){
        warning("Data contains NAs. These observations will be substituted by zeroes.", call.=FALSE);
        data[is.na(data)] <- 0;
    }

    if(occurrence=="n"){
        probability <- "n";
    }

    # Define obs, the number of observations of in-sample
    obsInSample <- nrow(data) - holdout*h;

    # Define obsAll, the overal number of observations (in-sample + holdout)
    obsAll <- nrow(data) + (1 - holdout)*h;

    # If obsInSample is negative, this means that we can't do anything...
    if(obsInSample<=2){
        stop("Not enough observations in sample.", call.=FALSE);
    }
    # Define the actual values.
    dataFreq <- frequency(data);
    dataDeltat <- deltat(data);
    dataStart <- start(data);
    yInSample <- ts(matrix(data[1:obsInSample,],obsInSample,nSeries),start=dataStart,frequency=dataFreq);
    yForecastStart <- time(data)[obsInSample]+deltat(data);

    ot <- (yInSample!=0)*1;
    otAll <- (data!=0)*1;
    obsOnes <- apply(ot,2,sum);

    pFitted <- matrix(NA,obsInSample,nSeries);
    pForecast <- matrix(NA,h,nSeries);

    nParam <- matrix(0,2,4,dimnames=list(c("Estimated","Provided"),
                                         c("nParamInternal","nParamXreg",
                                           "nParamIntermittent","nParamAll")));
#### Fixed probability ####
    if(occurrence=="f"){
        if(!initialIsNumeric){
            pFitted[,] <- rep(apply(ot,2,mean),each=obsInSample);
            pForecast[,] <- rep(pFitted[obsInSample,],each=h);
            initial <- pFitted[1,];
        }
        else{
            pFitted[,] <- rep(initial,each=obsInSample);
            pForecast[,] <- rep(initial,each=h);
        }
        states <- rbind(pFitted,pForecast);
        logLik <- structure((sum(log(pFitted[ot==1])) + sum(log((1-pFitted[ot==0])))),df=nSeries,class="logLik");
        errors <- ts(ot-pFitted, start=dataStart, frequency=dataFreq);
        persistence <- NULL;
        nParam[1,1] <- nParam[1,4] <- nSeries;
        issModel <- NULL
    }
#### Logistic probability ####
    else if(occurrence=="l"){
        if(probability=="i"){
            Etype <- ifelse(Etype=="M","A",Etype);
            Ttype <- ifelse(Ttype=="M","A",Ttype);
            Stype <- ifelse(Stype=="M","A",Stype);
            model <- paste0(Etype,Ttype,damped,Stype);

            issModel <- list(NA);
            states <- list(NA);
            logLik <- 0;
            errors <- matrix(NA,obsInSample,nSeries);
            initialValues <- list(NA);
            initialSeasonValues <- list(NA);
            persistenceValues <- list(NA);
            occurrence <- switch(occurrence, "l"="odds-ratio", "f"="fixed", "n"="none");
            for(i in 1:nSeries){
                issModel <- oes(ot[,i],occurrence=occurrence,ic=ic,h=h,model=model,persistence=persistence,
                                     initial=initial,initialSeason=initialSeason,xreg=xreg,holdout=holdout);
                pFitted[,i] <- issModel$fitted;
                pForecast[,i] <- issModel$forecast;
                states[[i]] <- issModel$states;
                errors[,i] <- issModel$residuals;
                initialValues[[i]] <- issModel$initial;
                initialSeasonValues[[i]] <- issModel$initialSeason;
                persistenceValues[[i]] <- issModel$persistence;
                #### This needs to be modified
                # logLik <- logLik + logLik(issModel);
                #####
            }
            nComponents <- length(persistenceValues[[1]]);
            states <- matrix(unlist(states),nrow(states[[1]]),nSeries*ncol(states[[1]]),
                             dimnames=list(NULL,paste0(rep(paste0("Series",c(1:nSeries),", "),
                                                           each=ncol(states[[1]])),
                                                       colnames(states[[1]]))));
            initial <- matrix(unlist(initialValues),nSeries,length(initialValues[[1]]),
                              dimnames=list(paste0("Series",c(1:nSeries)),names(initialValues[[1]])));
            if(length(initialSeasonValues)!=0){
                initialSeason <- matrix(unlist(initialSeasonValues),nSeries,length(initialSeasonValues[[1]]),
                                        dimnames=list(paste0("Series",c(1:nSeries)),
                                                      paste0("Seasonal",c(1:length(initialSeasonValues[[1]])))));
            }
            persistence <- matrix(0,nSeries*nComponents,nSeries,
                                  dimnames=list(colnames(states),NULL));
            for(i in 1:nSeries){
                persistence[(i-1)*nComponents + (1:nComponents),i] <- persistenceValues[[i]];
            }

            model <- issModel$model;
            nParam[1,4] <- nParam[1,1] <- issModel$nParam[1,1]*nSeries;
            logLik <- structure((sum(log(pFitted[ot==1])) + sum(log((1-pFitted[ot==0])))),df=nSeries,class="logLik");
        }
        else{
            modelOriginal <- model;
            Etype <- "L";
            Ttype <- ifelse(Ttype=="M","A",Ttype);
            Stype <- ifelse(Stype=="M","A",Stype);
            model <- paste0(Etype,Ttype,damped,Stype);

            # This matrix contains all the possible outcomes for probabilities
            otOutcomes <- matrix(0,2^nSeries,nSeries);
            otFull <- matrix(NA,obsInSample,2^nSeries);
            for(i in 1:(2^nSeries)){
                otOutcomes[i,] <- rev(as.integer(intToBits(i-1))[1:nSeries]);
                otFull[,i] <- apply(ot==matrix(otOutcomes[i,],obsInSample,nSeries,byrow=T),1,all)*1;
            }

            otFull <- ts(otFull,start=dataStart,frequency=dataFreq);
            issModel <- ves(otFull,model=model,persistence=persistence,transition=transition,phi=phi,
                            initial=initial,initialSeason=initialSeason,ic=ic,h=h,xreg=xreg,holdout=holdout)

            states <- issModel$states;
            errors <- issModel$residuals;
            pFitted[,] <- issModel$fitted %*% otOutcomes;
            pForecast[,] <- issModel$forecast %*% otOutcomes;

            initial <- issModel$initial;
            initialSeason <- issModel$initialSeason;
            persistence <- issModel$persistence;

            model <- modelOriginal;
            nParam <- issModel$nParam;
            # logLik <- issModel$logLik;
            logLik <- structure((sum(log(pFitted[ot==1])) + sum(log((1-pFitted[ot==0])))),df=nSeries,class="logLik");
        }
    }
    ##### None #####
    else{
        states <- rep(1,obsAll);
        errors <- NA;
        pFitted <-rep(1,obsInSample);
        pForecast <-rep(1,h);
        logLik <- -Inf;
        issModel <- NULL
    }

    states <- ts(states, start=dataStart, frequency=dataFreq);
    pFitted <- ts(pFitted, start=dataStart, frequency=dataFreq);
    pForecast <- ts(pForecast, start=time(data)[obsInSample] + dataDeltat, frequency=dataFreq);

    output <- list(model=model, fitted=pFitted, forecast=pForecast, states=states,
                   variance=pForecast*(1-pForecast), logLik=logLik, nParam=nParam,
                   residuals=errors, data=otAll, persistence=persistence, initial=initial,
                   initialSeason=initialSeason, occurrence=occurrence, issModel=issModel,
                   probability=probability);

    return(structure(output,class="oves"));
}
