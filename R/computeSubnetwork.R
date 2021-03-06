#'Compute a subnetwork
#'@description compute a subnetwork from p-values of the nodes of a network.
#'@usage computeSubnetwork(edgelist, nodelist, pval, fc, fdr, pcol, internalid, method, hasatt, returnas)
#'@param edgelist a data frame of edges contains at least a source column (1st column) and a target column (2nd column).
#'@param nodelist a data frame of nodes contains node attributes e.g. node id, node name, node xref. Default is NULL.
#'@param pval a numeric vector or a two-column data frame of statistical values e.g. p-values.
#'If \code{pval} is a vector, the name attributes must be identical to the names of network nodes.
#'If \code{pval} is a data frame, 1st column contains the network nodes and 2nd column contains statistical values.
#'@param fc a numeric vector of fold changes with name attributes identical to the names of network nodes. Default is NULL.
#'@param fdr a numeric value specifying false discovery rate. Default is 0.05.
#'@param pcol a string specifying columnname containing p-values. This parameter is only for accepting the input from GUI.
#'@param internalid a logical value indicating whether the network nodes are neo4j ids, if TRUE (default).
#'It has no effect if there is no database installed.
#'@param method a string specifying the method used to compute the subnetwork. Default is bionet.
#'@param hasatt a logical value indicating whether node attributes are kept already. Used by GUI.
#'@param returnas a string specifying output type. It can be one of dataframe, list, json. Default is dataframe.
#'@details
#'For the method \code{bionet}, the function wraps around the main steps of \pkg{\link{BioNet}} including \code{\link{fitBumModel}}, \code{\link{scoreNodes}}, \code{\link{runFastHeinz}}
#'to compute a subnetwork.
#'@return list of network information with the following components:
#'
#'nodes:
#'
#'\code{nodeAttributes} = node attributes provided
#'
#'\code{score} = node score if the method is \code{bionet}: positive values = signal content and negative values = background noise
#'
#'edges:
#'
#'\code{source, target}
#'
#'\code{edgeAttributes} = edge attributes provided
#'
#'Return empty list if error or found nothing.
#'@author Kwanjeera W \email{kwanich@@ucdavis.edu}
#'@references Beisser D., Klau GW., Dandekar T., Müller T. and Dittrich MT. (2010) BioNet: an R-Package for the functional analysis of biological networks. Bioinformatics, 26(8):1129-30
#'@references Dittrich MT., Klau GW., Rosenwald A., Dandekar T., Müller T. (2008) Identifying functional modules in protein-protein interaction networks: an integrated exact approach. Bioinformatics, 24(13):i223-31
#'@seealso \code{\link{fitBumModel}}, \code{\link{scoreNodes}}, \code{\link{runFastHeinz}}
#'@examples
#'#simnw <- computeSimilarity(c(1110,10413,196,51,311,43,764,790)) #compute similarity network for given pubchem compounds
#'#pval <- data.frame(pubchem=c(1110,10413,196,51,311,43,764,790), stat=runif(8, 0, 0.06)) #statistical values of pubchem compounds
#'#result <- computeSubnetwork(simnw$edges, simnw$nodes, pval=pval, internalid = F)
#'@export
computeSubnetwork <- function(edgelist, nodelist=NULL, pval, fc=NULL, fdr=0.05, pcol=NULL, internalid=TRUE, method="bionet", hasatt=FALSE, returnas="dataframe") UseMethod("computeSubnetwork")
#'@export
computeSubnetwork.default <- function (edgelist, nodelist=NULL, pval, fc=NULL, fdr=0.05, pcol=NULL, internalid=TRUE, method="bionet", hasatt=FALSE, returnas="dataframe"){
  out <- tryCatch(
    {
    tmparg <- try(method <- match.arg(tolower(method), c("bionet","sili"), several.ok = FALSE), silent = TRUE)
    if (class(tmparg) == "try-error") {
      stop("argument 'method' is not valid, choose one from the list: bionet,sili")
    }
    nodelist = nodelist[!duplicated(nodelist[,2]),]
    flagdf = FALSE
    if(!is.null(pcol)){#get input data from GUI
      datinput = pval #keep input data
      flagdf = TRUE
      if(!is.null(pval$grinn)){
        pval = pval[,c('grinn',pcol)]
      }else if(!is.null(pval$PubChem)){
        pval = pval[,c('PubChem',pcol)]
        colnames(datinput) = gsub("PubChem","grinn",colnames(datinput))
      }else if(!is.null(pval$pubchem)){
        pval = pval[,c('pubchem',pcol)]
        colnames(datinput) = gsub("pubchem","grinn",colnames(datinput))
      }else if(!is.null(pval$uniprot)){
        pval = pval[,c('uniprot',pcol)]
        colnames(datinput) = gsub("uniprot","grinn",colnames(datinput))
      }else if(!is.null(pval$ensembl)){
        pval = pval[,c('ensembl',pcol)]
        colnames(datinput) = gsub("ensembl","grinn",colnames(datinput))
      }
    }
    if (class(pval) == "data.frame") {
      if(internalid){#format pval: 1st id, 2nd pval, ... ,use only 1st and 2nd column
        pv = pval[,2]
        pv = gsub('^$',1,pv) #replace blank to 1
        pv = as.numeric(pv)
        names(pv) = pval[,1]
        pval = pv
      }else{#format pval: 1st gid, 2nd pval, ... ,use only 1st and 2nd column, change gid to id
        merged = merge(nodelist, pval, by.x = colnames(nodelist)[2], by.y = colnames(pval)[1], all.y = TRUE)
        pv = merged[,ncol(nodelist)+1]
        pv = gsub('^$',1,pv) #replace blank to 1
        pv = as.numeric(pv)
        names(pv) = merged$id
        pval = pv
      }
    }
    if(tolower(method) == 'bionet'){
      outnw = callBionet(edgelist, nodelist, pval[pval!=0], fdr)
      if(flagdf){#keep input data
        networknode = outnw$nodes
        if(hasatt){
          networknode = merge(networknode[,1:5],datinput,by.x='gid',by.y='grinn',all.x=TRUE)
        }else{
          networknode = merge(networknode,datinput,by.x='gid',by.y='grinn',all.x=TRUE)
        }
        networknode = networknode[,c(2,1,3:ncol(networknode))]
        networknode[is.na(networknode)] = ""
        outnw$nodes = networknode
      }
    }else if(tolower(method) == 'sili'){
      stop('Under development')
    }else{
      stop('Unknown method')
    }
    ## output
    switch(returnas,
      dataframe = outnw,
      list = list(nodes= split(outnw$nodes, seq(nrow(outnw$nodes))), edges=split(outnw$edges, seq(nrow(outnw$edges)))),
      json = list(nodes=jsonlite::toJSON(outnw$nodes), edges=jsonlite::toJSON(outnw$edges)),
      stop("Error: incorrect 'returnas' type"))
  },error=function(e) {
    message(e)
    cat("\nError: RETURN no network ..\n")
    switch(returnas,
           dataframe = list(nodes=data.frame(), edges=data.frame()),
           list = list(nodes=list(), edges=list()),
           json = list(nodes=list(), edges=list()))
  })
  return(out)
}
