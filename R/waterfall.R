intersect.foo <-function(tot1,tot2,ab){
  # intersect between tot1-tot2 segment and ab point
  x1 = tot1[1];y1=tot1[2];x2=tot2[1];y2=tot2[2];a=ab[1];b=ab[2]
  slope = (y2-y1)/(x2-x1)

  int.x=(slope*x1 + a/slope + b -y1)/(slope+1/slope)
  int.y=(-x1 + a + b*slope + y1/slope)/(slope+1/slope)
  return(c(int.x,int.y))
}

inside_check.foo <-function(tot1,tot2,ab){
  int <-intersect.foo(tot1,tot2,ab)
  all((tot1<=int& int<=tot2)|(tot2<=int& int<=tot1))
}

#' @importFrom stats dist
distance.foo <-function(tot1,tot2,ab){
  int <-intersect.foo(tot1,tot2,ab)
  return(stats::dist(rbind(int,ab)))
}

`%notin%` <- function(x,y) !(x %in% y)

#' @importFrom stats dist
unit_vector.foo <-function(x,y){
  x <-as.numeric(x)
  y <-as.numeric(y)
  (y-x)/(stats::dist(rbind(x,y)))
}

crossvec <- function(x,y){
  if(length(x)!=2 |length(y)!=2) stop('bad vectors')
  cv <- x[1]*y[2]-x[2]*y[1]
  return(invisible(cv))
}

crossvec_direction <-function(tot1,tot2,ab){
  if ((crossvec(tot2-tot1,ab-tot1))>=0){
    return(1)
  } else{
    return(-1)
  }
}

#' Execute waterfall
#'
#' @param x your data
#' @param k the number of clusters
#' @param x.reverse whether or not to reverse the trajectory
#'
#' @export
#' @importFrom stats prcomp kmeans dist
#' @importFrom ape mst
#' @importFrom graphics plot points segments
pseudotimeprog.foo <- function(x, k=10, x.reverse=F){
  r <- stats::prcomp(t(x))
  y <- r$x*matrix(r$sdev^2/sum(r$sdev^2),nrow=nrow(r$x),ncol=ncol(r$x),byrow=T)
  #y <-y[order(y[,1]),]
  #u <- r$rotation

  # kmeans
  r <- stats::kmeans(y,k)
  z <- r$centers
  z <- z[order(z[,1]),,drop=F]
  rownames(z) <-paste0("t",1:nrow(z))
  m <- ape::mst(stats::dist(z))

  t.names <-names(which(colSums(m!=0)==1))[1] # There are two ends, then use the left most one.
  for (i in 1:nrow(m)){
    t.names <-append(t.names,names(which(m[t.names[i],]==1))[which(names(which(m[t.names[i],]==1)) %notin% t.names)])
  }

  y2d <-y[,1:2]
  #y2d <-y2d[order(y2d[,1]),]
  z2d <-z[,1:2]
  z2d <-z2d[t.names,]

  time_start.i <-0
  updatethis.dist <-rep(Inf,nrow(y2d))
  updatethis.time <-rep(0,nrow(y2d))
  update.updown <-rep(0,nrow(y2d))
  pseudotime.flow <-c(0)

  for (i in 1:(nrow(z2d)-1)){
    # distance between this z2d.i and all y2d
    dot.dist.i <-apply(y2d,1,function(X){stats::dist(rbind(X,z2d[i,]))})

    # distance between this z2d.i-z2d.i+1 segment and "insider" y2d
    inside_this_segment <-which(apply(y2d,1,function(X){inside_check.foo(z2d[i,],z2d[i+1,],X)}))
    seg.dist.i <-rep(Inf,nrow(y2d))
    seg.dist.i[inside_this_segment] <-apply(y2d,1,function(X){distance.foo(z2d[i,],z2d[i+1,],X)})[inside_this_segment]

    # intersect coordinate between this z2d.i-z2d.i+1 segment and all y2d
    intersect.i <-t(apply(y2d,1,function(X){intersect.foo(z2d[i,],z2d[i+1,],X)}))

    # this z2d.i-z2d.i+1 segment's unit vector
    seg_unit_vector <-unit_vector.foo(z2d[i,],z2d[i+1,])

    # UPDATE
    # 2. idx for the shortest distance at this round (either dot or seg)
    update.idx <-apply(cbind(dot.dist.i,seg.dist.i,updatethis.dist),1,which.min)
    # 3. update the pseudotime for y2ds with the short distance from the z2d.i
    updatethis.time[which(update.idx==1)] <-time_start.i
    # 4. update the pseudotime for y2ds with the short distance from the z2d.i-z2d.i+1 segment
    relative_cordinates <-t(apply(intersect.i[which(update.idx==2),,drop=F],1,function(X){seg_unit_vector%*%(X-z2d[i,])}))
    updatethis.time[which(update.idx==2)] <-time_start.i + relative_cordinates
    # 1. update the shortest distance
    updatethis.dist <-apply(cbind(dot.dist.i,seg.dist.i,updatethis.dist),1,min)

    update.updown[which(update.idx==1)] <-c(apply(y2d,1,function(X){crossvec_direction(z2d[i,],z2d[i+1,],X)})*dot.dist.i)[which(update.idx==1)]
    update.updown[which(update.idx==2)] <-c(apply(y2d,1,function(X){crossvec_direction(z2d[i,],z2d[i+1,],X)})*seg.dist.i)[which(update.idx==2)]

    # update time for the next round
    time_start.i <-time_start.i + stats::dist(rbind(z2d[i,],z2d[i+1,]))
    pseudotime.flow <-append(pseudotime.flow,time_start.i)
  }

  # For the y2ds that are closest to the starting z2d
  i=1
  dot.dist.i <-apply(y2d,1,function(X){stats::dist(rbind(X,z2d[i,]))})
  if (length(start.idx <-which(dot.dist.i <= updatethis.dist))>0) {
    intersect.i <-t(apply(y2d,1,function(X){intersect.foo(z2d[i,],z2d[i+1,],X)}))
    seg_unit_vector <-unit_vector.foo(z2d[i,],z2d[i+1,])
    relative_cordinates <-0 + t(apply(intersect.i,1,function(X){seg_unit_vector %*% (X-z2d[i,])}))[start.idx]
    updatethis.time[start.idx] <-relative_cordinates
    seg.dist.i <-apply(y2d,1,function(X){distance.foo(z2d[i,],z2d[i+1,],X)})
    update.updown[start.idx] <-c(apply(y2d,1,function(X){crossvec_direction(z2d[i,],z2d[i+1,],X)})*seg.dist.i)[start.idx]
  }
  # For the y2ds that are closest to the arriving z2d
  i=nrow(z2d)
  dot.dist.i <-apply(y2d,1,function(X){stats::dist(rbind(X,z2d[i,]))})
  if (length(arrive.idx <-which(dot.dist.i <= updatethis.dist))>0) {
    intersect.i <-t(apply(y2d,1,function(X){intersect.foo(z2d[i-1,],z2d[i,],X)}))
    seg_unit_vector <-unit_vector.foo(z2d[i-1,],z2d[i,])
    relative_cordinates <-time_start.i + as.numeric(t(apply(intersect.i,1,function(X){seg_unit_vector %*% (X-z2d[i,])})))[arrive.idx]
    updatethis.time[arrive.idx] <-relative_cordinates
    seg.dist.i <-apply(y2d,1,function(X){distance.foo(z2d[i-1,],z2d[i,],X)})
    update.updown[arrive.idx] <-c(apply(y2d,1,function(X){crossvec_direction(z2d[i-1,],z2d[i,],X)})*seg.dist.i)[arrive.idx]
  }

  pseudotime <-updatethis.time
  pseudotime.y <-update.updown
  pseudotime.flow <-pseudotime.flow

  if (x.reverse){
    pseudotime <- -pseudotime
    pseudotime.flow <- -pseudotime.flow
  }

  pseudotime_range <-max(pseudotime)-min(pseudotime)

  pseudotime.flow <-pseudotime.flow-min(pseudotime)
  pseudotime.flow <-pseudotime.flow/pseudotime_range

  pseudotime <-pseudotime-min(pseudotime)
  pseudotime <-pseudotime/pseudotime_range

  df <- data.frame(y[,1:2], pseudotime, pseudotime.y)
  attr(df, "flow") <- data.frame(PC1 = pseudotime.flow, PC2 = rep(0, length(pseudotime.flow)))
  df
}

#' Plotting the waterfall results with ggplot2
#'
#' @param df the output from waterfall
#'
#' @import ggplot2
#' @export
plot_waterfall <- function(df) {
  flow <- attr(df, "flow")
  ggplot() +
    geom_point(aes(pseudotime, pseudotime.y, colour = pseudotime), df, size = 5) +
    geom_point(aes(PC1, PC2), flow, size = 2, colour = "red") +
    geom_path(aes(PC1, PC2), flow, size = 2, colour = "red") +
    scale_colour_distiller(palette = "RdBu") +
    theme_classic()
}
