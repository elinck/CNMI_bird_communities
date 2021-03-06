################################################
# analysis of mariana islands bird survey data
# E. Linck, E. Fricke, H. Rogers 
################################################

### load libraries, clean data

#setwd("~/Dropbox/Marianas/CNMI_bird_communities/")

# Define functions
'%!in%' <- function(x,y)!('%in%'(x,y))

ipak <- function(pkg){
  new.pkg <- pkg[!(pkg %in% installed.packages()[, "Package"])]
  if (length(new.pkg))
    install.packages(new.pkg, dependencies = TRUE)
  sapply(pkg, require, character.only = TRUE)
}

# load libraries
packages <- c("unmarked", "reshape", "plyr", "FD", "sciplot",
              "vegan", "ggplot2", "ggmap", "mapdata", "maps", "lme4",
              "multcomp")

ipak(packages)


# Read in data. Each row = one species at each point. 
birdcounts <- read.table("./data/fulldata.txt", header=T) #load your data.
str(birdcounts)

# change format of date
birdcounts$date <- as.Date(birdcounts$date, "%m/%d/%y")

# make species levels lowercase
birdcounts$spp <- as.factor(as.character(tolower(birdcounts$spp)))

# make unique identifier for each count (point plus date) and each site date (site plus date)
birdcounts$pointdate <- as.factor(paste(birdcounts$point, birdcounts$date, sep=" "))
birdcounts$sitedate <- as.factor(paste(birdcounts$site, birdcounts$date, sep=" "))

# pull out point-level information, and put in alphabetical order by point 
# to be used later, after we use the formatDataDist function
point.data <- birdcounts[!duplicated(birdcounts[2:4]),]
point.data <- point.data[order(point.data$point),]
point.data <- point.data[,-c(5:9)]

# change from wide to long format
birdcounts.long <- untable(birdcounts[,c(1:6,8:11)], num=birdcounts[,7])

# remove data for certain species that we have too few estimates for (<10)
spp.included <- levels(birdcounts.long$spp)[which(levels(birdcounts.long$spp) %!in% c("coku","mela","gyal"))]
birdcounts.long <- birdcounts.long[which(birdcounts.long$spp %in% spp.included),]
birdcounts.long$spp <- as.factor(as.character(birdcounts.long$spp)) # makes r forget those other levels of this factor

# Remove the 6th occasion to achieve equal samples for each site (Tinian just has 5 occasions, rather than 6)
# Otherwise, the code interprets it as though Tinians just has super low densities
birdcounts.long <- subset(birdcounts.long, occasion < 6)

birdcounts.long$occasion <- as.factor(birdcounts.long$occasion)

### Use unmarked package to get abundance estimates for each point

# make empty output dataframes that can handle the data from predict()
lambda.out <- data.frame(spp=character(),Predicted=numeric(),SE=numeric(),lower=numeric(),upper=numeric(),point=character())
phi.out <- lambda.out #do the same for phi
det.out <- lambda.out #do the same for det

# Determine which spp were recorded on which site
present <- as.data.frame(ifelse(table(list(birdcounts.long$island,birdcounts.long$spp))>0,T,F))

# Make blank umdata to fill in
distance.cuttoffs <- c(0, 5, 10, 15, 20, 30, 40, 50, 100, 200)

blank.umdata <- formatDistData(birdcounts.long, 
                               distCol = "dist",
                               transectNameCol = "point",
                               dist.breaks = distance.cuttoffs,
                               occasionCol = "occasion")
blank.umdata <- ifelse(blank.umdata>-1,0,0)

# # Load existing saved model outputs below, or uncomment to run models again
# # Now for the models
# time1<-Sys.time()
# 
# for(i in 1:length(levels(birdcounts.long$spp))){
#   # create subset of data for one focal spp
#   sp.set <- subset(birdcounts.long, spp==levels(birdcounts.long$spp)[i])
#   
#   #### don't get estimates for islands where we didn't see the spp
#   sp.set$point <- as.factor(as.character(sp.set$point))
#   sp.set$island <- as.factor(as.character(sp.set$island))
#   sp.set$site <- as.factor(as.character(sp.set$site))
#   
#   #get into binned format, with each point seen as a replicate by the number of dates sampled (OccasioncCol="date")
#   sp.set.umdata <- formatDistData(sp.set, distCol="dist",
#                                   transectNameCol="point", 
#                                   dist.breaks=distance.cuttoffs,
#                                   occasionCol="occasion")
#   sp.set_rows <- row.names(sp.set.umdata)
#   
#   # Add in observed data into correct format with true zeros present
#   sp.blank.umdata <- blank.umdata
#   sp.blank.umdata[sp.set_rows,1:((length(distance.cuttoffs)-1)*5)] <- sp.set.umdata
#   sp.set.umdata <- sp.blank.umdata[,1:((length(distance.cuttoffs)-1)*5)]
#   # Now overwrite the row names
#   sp.set_rows <- row.names(sp.set.umdata)
#   
#   point.data.set <- point.data
#   point.data.set <- point.data.set[which(as.numeric(point.data.set$island) %in% which(present[,i]==T)),] # Will subset to islands where it's present later for the umdata file as well
#   point.data.set$point <- factor(point.data.set$point)
#   point.data.set$island <- factor(point.data.set$island)
#   point.data.set$site <- factor(point.data.set$site)
#   sp.set.umdata <- sp.set.umdata[which(as.character(point.data$island) %in% rownames(present)[which(present[,i]==T)]),] # This is where we subset to islands present
#   # Now overwrite the row names again!
#   sp.set_rows <- row.names(sp.set.umdata)
#   
#   sp.set.umfull <- cbind(sp.set.umdata,sp.set_rows, point.data.set)
#   
#   # Need to make it forget all the factor levels not represented in sp.set.umfull
#   sp.set.umfull$point <- factor(sp.set.umfull$point)
#   sp.set.umfull$island <- factor(sp.set.umfull$island)
#   sp.set.umfull$site <- factor(sp.set.umfull$site)
#   
#   #create dataframe in UMF format # island=sp.set.umfull$island, 
#   sp.set.umf <- unmarkedFrameGDS(y = sp.set.umdata,  #columns should be labeled dc1,dc2, dc3, dc4 and so on, for each distance class and values within are counts of that bird species at that point for that distance class. 
#                                  siteCovs = data.frame(site=sp.set.umfull$site, point=sp.set.umfull$point), #site covariates are probably island, maybe site, and maybe point (not sure how they deal with repeated measures)
#                                  dist.breaks = c(0, 5, 10, 15, 20, 30, 40, 50, 100, 200),  #these are the distances at which you enter a new distance class
#                                  numPrimary = 5,#numPrimary=ifelse(i==5,5,6), #number of surveys at each point
#                                  survey = "point", unitsIn = "m")  #survey style is point, not transect.  unitsIn are meters, I suspect
#   mod <- gdistsamp(~point, ~1, ~1,data=sp.set.umf, keyfun="halfnorm", output="density", unitsOut="ha",
#                    starts=c(1,rep(0,dim(sp.set.umfull)[1]-1),3,3),
#                    method = ifelse(i==7, "SANN", "BFGS")
#                    )
#   
#   # Make dataframe for predictions
#   newdf<-data.frame(point=factor(point.data.set$point))
#   
#   # Make the predictions
#   lambda <- predict(mod, newdata=newdf, type="lambda", appendData=TRUE)
#   phi <- predict(mod, newdata=newdf, type="phi", appendData=TRUE)
#   det <- predict(mod, newdata=newdf, type="det", appendData=TRUE)
#   
#   # Get ready to paste these on to the end of the output dataframes
#   spp <- rep(levels(birdcounts.long$spp)[i],dim(lambda)[1])
#   lambda <- cbind(spp,lambda)
#   phi <- cbind(spp,phi)
#   det <- cbind(spp,det)
#   
#   # Attach to ouput
#   lambda.out <- rbind(lambda.out,lambda)
#   phi.out <- rbind(phi.out,phi)
#   det.out <- rbind(det.out,det)
#   
#   print(warnings())
#   print(mod)
#   print(paste(i,"out of",length(levels(birdcounts.long$spp)),"done at", Sys.time(),sep=" "))
# }
# time2<-Sys.time()
# 
# 
# 
# write.csv(lambda.out,"lambda.out.csv")
# write.csv(phi.out,"phi.out.csv")
# write.csv(det.out,"det.out.csv")

# read in saved values
lambda.out <- read.csv("./data/lambda.out.csv",row.names=1)
phi.out <- read.csv("./data/phi.out.csv",row.names=1)
det.out <- read.csv("./data/det.out.csv",row.names=1)

# Convert to common name 4-letter codes
spp.converter<-c("apop"="mist",
                 "clma"="gowe",
                 "dima"="bldr",
                 "gaxa"="wtgd",
                 "gaga"="chic",
                 "mota"="timo",
                 "myru"="mihe",
                 "ptro"="mafd",
                 "rhru"="rufa",
                 "stbi"="iscd",
                 "toch"="cokf",
                 "zoco"="brwe")

lambda.out$spp<-revalue(lambda.out$spp,spp.converter)
phi.out$spp<-revalue(phi.out$spp,spp.converter)
det.out$spp<-revalue(det.out$spp,spp.converter)

fd.mat <- read.csv("./data/FD_matrix_20170504.csv",row.names=1)
fd.mat <- fd.mat[,1:10]# Remove the detailed foraging location data 
#fd.mat <- fd.mat[,-6] #No seed eaters
head(fd.mat)

abund <- lambda.out[,c(1,2,6)]
library(reshape)
abund.wide <- reshape(abund,direction="wide",v.names="Predicted",idvar="point",timevar="spp")
colnames(abund.wide) <- gsub("Predicted.","",colnames(abund.wide))

head(abund.wide)
abund.wide[is.na(abund.wide)] <- 0 # These are true zeros

# Make each point rowname and so the dataframe only has numeric abundance values
rownames(abund.wide) <- abund.wide[,1]
abund.wide <- abund.wide[,c(2:dim(abund.wide)[2])]

# Correct order
abund.wide <- abund.wide[,order(colnames(abund.wide))]
fd.mat <- fd.mat[order(rownames(fd.mat)),]
fd.mat <- fd.mat[,3:dim(fd.mat)[2]]# Get rid of "Scientific" and "English" names
dfvals <- dbFD(x=fd.mat,a=abund.wide)
dfvals$FDiv # I think these warnings are okay given the absence of some species

# Put together the dataframe for analysis
fd.df <- birdcounts[!duplicated(paste(birdcounts$island,birdcounts$point)),c("island","site","point")]
rownames(fd.df) <- fd.df$point

fd.df$total.abund <- rowSums(abund.wide)[rownames(fd.df)]
fd.df$shannon.div <- diversity(abund.wide)[rownames(fd.df)]
fd.df$FDiv <- dfvals$FDiv[rownames(fd.df)]
fd.df$FEve <- dfvals$FEve[rownames(fd.df)]
fd.df$FDis <- dfvals$FDis[rownames(fd.df)]
fd.df[,(dim(fd.df)[2]:(dim(fd.df)[2]+dim(dfvals$CWM)[2]))] <- dfvals$CWM[rownames(fd.df),] # This adds a bunch of columns for CWM values


# Relevel so Saipan is reference
fd.df$island <- relevel(fd.df$island, ref="Tinian")
fd.df$island <- relevel(fd.df$island, ref="Saipan")

# # This is duplicated because of the more efficient for loop below.... Think I can delete.
# head(fd.df)
# 
# fd.mod0 <- lmer(FDiv~1+(1|site),dat=fd.df)
# fd.mod <- lmer(FDiv~island+(1|site),dat=fd.df)
# summary(fd.mod)
# anova(fd.mod0,fd.mod) # Likelihood ratio test shows that island is a strong predictor of FD
# 
# abund.mod0 <- lmer(total.abund~1+(1|site),dat=fd.df)
# abund.mod <- lmer(total.abund~island+(1|site),dat=fd.df)
# summary(fd.mod)
# anova(abund.mod0,abund.mod) # LRT shows that island is a strong predictor of total abundance
# 
# feve.mod0 <- lmer(FEve~1+(1|site),dat=fd.df)
# feve.mod <- lmer(FEve~island+(1|site),dat=fd.df)
# summary(feve.mod)
# anova(feve.mod0,feve.mod) # LRT shows that island is NOT a strong predictor of FEve
# 
# shan.mod0 <- lmer(shannon.div~1+(1|site),dat=fd.df)
# shan.mod <- lmer(shannon.div~island+(1|site),dat=fd.df)
# summary(shan.mod)
# anova(shan.mod0,shan.mod) # LRT shows that island is a strong predictor of shannon div
# 
# tapply(fd.df$FDiv,fd.df$island,mean)
# tapply(fd.df$total.abund,fd.df$island,mean)
# colnames(fd.df)
# #tapply(fd.df$Fruit,fd.df$island,mean)
# tapply(fd.df$Diet.Fruit,fd.df$island,mean)

colnames(fd.df)

#cols.to.test <- c(1:9,11)
cols.to.test <- c(4:13,15:16)
analysis.out <- as.data.frame(colnames(fd.df)[cols.to.test],strings.as.factors=F)
colnames(analysis.out)[1] <- "response"

analysis.out$saipan <- c(NA)
analysis.out$tinian <- c(NA)
analysis.out$rota <- c(NA)
analysis.out$saipan.ci.lo <- c(NA)
analysis.out$tinian.ci.lo <- c(NA)
analysis.out$rota.ci.lo <- c(NA)
analysis.out$saipan.ci.hi <- c(NA)
analysis.out$tinian.ci.hi <- c(NA)
analysis.out$rota.ci.hi <- c(NA)
analysis.out$lrt <- c(NA)
analysis.out$chisq <- c(NA)
analysis.out$sai.let <- c(NA)
analysis.out$tin.let <- c(NA)
analysis.out$rot.let <- c(NA)

for(i in cols.to.test){
  mod0 <- lmer(fd.df[,i]~1+(1|site),dat=fd.df)
  mod1 <- lmer(fd.df[,i]~island+(1|site),dat=fd.df)
  mod <- lmer(fd.df[,i] ~ island + -1 + (1|site), dat = fd.df) # Change format so I can get confidence intervals for each island
  analysis.out[which(analysis.out$response==colnames(fd.df)[i]),2:4] <- fixef(mod)
  ci <- confint(mod,parm=c("islandSaipan","islandTinian","islandRota"))
  analysis.out[which(analysis.out$response==colnames(fd.df)[i]),5:7] <- ci[,1]
  analysis.out[which(analysis.out$response==colnames(fd.df)[i]),8:10] <- ci[,2]
  analysis.out[which(analysis.out$response==colnames(fd.df)[i]),11] <- anova(mod0,mod1)$"Pr(>Chisq)"[2]
  analysis.out[which(analysis.out$response==colnames(fd.df)[i]),12] <- anova(mod0,mod1)$"Chisq"[2]
  analysis.out[which(analysis.out$response==colnames(fd.df)[i]),13:15] <- cld(glht(mod1, linfct = mcp(island="Tukey")))$mcletters$Letters

}


# Species richness. 
# This doesn't use the abundance data, so we're going back to the bidcounts data 
# to just get richness at each pointcount, so a little clunky that it doesn't
# fit in the same for loop
rich.dat <- birdcounts.long[!duplicated(birdcounts.long[,c(1:6)]),]
rich.dat$pointdate <- as.factor(as.character(rich.dat$pointdate))
richness.pointdate <- table(rich.dat$pointdate)
rich.no.duplicates <- rich.dat[!duplicated(rich.dat$pointdate),]
rich.no.duplicates <- rich.no.duplicates[order(rich.no.duplicates$pointdate),]
rich.no.duplicates <- cbind(rich.no.duplicates,richness.pointdate)

# Relevel so Saipan is reference
rich.no.duplicates$island <- relevel(rich.no.duplicates$island, ref="Tinian")
rich.no.duplicates$island <- relevel(rich.no.duplicates$island, ref="Saipan")

# Do the analysis
mod.rich0 <- lmer(Freq ~ 1 + (1|site),data=rich.no.duplicates)
mod.rich1 <- lmer(Freq ~ island + (1|site),data=rich.no.duplicates)
mod.rich <- lmer(Freq ~ island + -1 + (1|site), data=rich.no.duplicates)
# Get confidence intervals
ci <- confint(mod.rich,parm=c("islandSaipan","islandTinian","islandRota"))
anova(mod.rich0,mod.rich1,mod.rich)

analysis.out[(dim(analysis.out)[1]+1),2:4] <- fixef(mod.rich)
analysis.out[(dim(analysis.out)[1]),5:7] <- ci[,1]
analysis.out[(dim(analysis.out)[1]),8:10] <- ci[,2]
analysis.out[(dim(analysis.out)[1]),11] <- anova(mod.rich0,mod.rich1)$"Pr(>Chisq)"[2]
analysis.out[(dim(analysis.out)[1]),12] <- anova(mod.rich0,mod.rich1)$"Chisq"[2]
analysis.out$response <- as.character(analysis.out$response)
analysis.out[(dim(analysis.out)[1]),1] <- "richness"
analysis.out[which(analysis.out$response=="richness"),13:15] <- cld(glht(mod.rich1, linfct = mcp(island="Tukey")))$mcletters$Letters



# Get a long-format analysis.out for ease in making plots.
analysis.long <- reshape(analysis.out[1:12],varying=list(c(2:4),c(5:7),c(8:10)),idvar="response",direction="long")
colnames(analysis.long)[c(4:7)] <- c("island","estimate","ci.lo","ci.hi")
analysis.long$island <- c("Saipan","Tinian","Rota")[analysis.long$island]
analysis.long$island <- factor(analysis.long$island,levels=c("Saipan","Tinian","Rota"))


# Some helper function for plots
range1 <- function(x) range(x)[1]
range2 <- function(x) range(x)[2]

q25 <- function(x) quantile(x,prob=0.25)
q75 <- function(x) quantile(x,prob=0.75)


### five panel with Total Abundance, Shannon Diversity, Functional Diversity, Func Evenness
pdf("fiveplots.pdf",width = 6, height = 9, useDingbats=FALSE)
abund.div.cols <- c("total.abund","richness","shannon.div","FEve","FDiv")
par(mfrow=c(3,2),pin=c(1.5,2.5))
#par(mfrow=c(3,2),pin=c(1,1),mar=c(0.5,0.5,0.5,0.5))
for(i in 1:length(abund.div.cols)){
  if(i==2){
    plot.new()
  }
  
  col.set <- subset(analysis.long,analysis.long$response==abund.div.cols[i])
  plot(estimate~c(1,2,3),data=col.set,
       xlim=c(0.75,3.25),
       ylim=c(min(col.set[,5:7])*.9,max(col.set[,5:7])*1.1),
       frame.plot=F,
       ylab="",
       xlab="",
       las=1,
       pch=c(21:23),
       xaxt="n",cex=1.5)
  text(1, max(col.set[,5:7])*1.1, c("A", "B", "C", "D", "E")[i], cex = 1.5)
  mtext(c("Total Abundance (birds/ha)","Richness","Shannon Diversity","Functional Evenness","Functional Diversity")[i],
        side=2,
        line=4)
  segments(x0=c(1,2,3),y0=(col.set$ci.lo),y1=(col.set$ci.hi),
           lwd=10,
           col=c("grey30","grey60","grey90"),
           lend="butt")
  points(estimate~c(1,2,3),data=col.set,
         pch=c(21:23),cex=1.5,
         bg="white")
  text(1:3, min(col.set[,5:7])*.9, 
       analysis.out[which(analysis.out$response==abund.div.cols[i]), 13:15],
       cex = 1.2)
         
  if(i==length(abund.div.cols)){
    axis(1,at=c(1,2,3),labels=c("Saipan","Tinian","Rota"),cex.axis=1.3)
  }
  if(i==length(abund.div.cols)-1){
    axis(1,at=c(1,2,3),labels=c("Saipan","Tinian","Rota"),cex.axis=1.3)
  }
}
dev.off()

# # Load existing saved model outputs below, or uncomment to run models again
# ### rerun unmarked for island specific models
# 
# lambda.island.out <- data.frame(spp=character(),Predicted=numeric(),SE=numeric(),lower=numeric(),upper=numeric(),point=character())
# phi.island.out <- lambda.island.out #do the same for phi
# det.island.out <- lambda.island.out #do the same for det
# 
# # Now for the models
# time1<-Sys.time()
# 
# for(i in 1:length(levels(birdcounts.long$spp))){
#   # create subset of data for one focal spp
#   sp.set <- subset(birdcounts.long, spp==levels(birdcounts.long$spp)[i])
#   
#   #### don't get estimates for islands where we didn't see the spp
#   sp.set$point <- as.factor(as.character(sp.set$point))
#   sp.set$island <- as.factor(as.character(sp.set$island))
#   sp.set$site <- as.factor(as.character(sp.set$site))
#   
#   #get into binned format, with each point seen as a replicate by the number of dates sampled (OccasioncCol="date")
#   sp.set.umdata <- formatDistData(sp.set, distCol="dist",
#                                   transectNameCol="point", 
#                                   dist.breaks=distance.cuttoffs,
#                                   occasionCol="occasion")
#   sp.set_rows <- row.names(sp.set.umdata)
#   
#   # Add in observed data into correct format with true zeros present
#   sp.blank.umdata <- blank.umdata
#   sp.blank.umdata[sp.set_rows,1:((length(distance.cuttoffs)-1)*5)] <- sp.set.umdata
#   sp.set.umdata <- sp.blank.umdata[,1:((length(distance.cuttoffs)-1)*5)]
#   # Now overwrite the row names
#   sp.set_rows <- row.names(sp.set.umdata)
#   
#   point.data.set <- point.data
#   point.data.set <- point.data.set[which(as.numeric(point.data.set$island) %in% which(present[,i]==T)),] # Will subset to islands where it's present later for the umdata file as well
#   point.data.set$point <- factor(point.data.set$point)
#   point.data.set$island <- factor(point.data.set$island)
#   point.data.set$site <- factor(point.data.set$site)
#   sp.set.umdata <- sp.set.umdata[which(as.character(point.data$island) %in% rownames(present)[which(present[,i]==T)]),] # This is where we subset to islands present
#   # Now overwrite the row names again!
#   sp.set_rows <- row.names(sp.set.umdata)
#   
#   sp.set.umfull <- cbind(sp.set.umdata,sp.set_rows, point.data.set)
#   
#   # Need to make it forget all the factor levels not represented in sp.set.umfull
#   sp.set.umfull$point <- factor(sp.set.umfull$point)
#   sp.set.umfull$island <- factor(sp.set.umfull$island)
#   sp.set.umfull$site <- factor(sp.set.umfull$site)
#   
#   #create dataframe in UMF format # island=sp.set.umfull$island, 
#   sp.set.umf <- unmarkedFrameGDS(y = sp.set.umdata,  #columns should be labeled dc1,dc2, dc3, dc4 and so on, for each distance class and values within are counts of that bird species at that point for that distance class. 
#                                  siteCovs = data.frame(island=sp.set.umfull$island, point=sp.set.umfull$point), #site covariates are probably island, maybe site, and maybe point (not sure how they deal with repeated measures)
#                                  dist.breaks = c(0, 5, 10, 15, 20, 30, 40, 50, 100, 200),  #these are the distances at which you enter a new distance class
#                                  numPrimary = 5,#numPrimary=ifelse(i==5,5,6), #number of surveys at each point
#                                  survey = "point", unitsIn = "m")  #survey style is point, not transect.  unitsIn are meters, I suspect
#   if(length(levels(point.data.set$island))>1) {
#     mod <- gdistsamp(~island, ~1, ~1,data=sp.set.umf, keyfun="halfnorm", output="density", unitsOut="ha")#,
#     #starts=c(1,rep(0,dim(sp.set.umfull)[1]-1),3,3),
#     #method = ifelse(i==7, "SANN", "BFGS")
#     #)
#   } else {
#     mod <- gdistsamp(~1, ~1, ~1,data=sp.set.umf, keyfun="halfnorm", output="density", unitsOut="ha")
#   }
#   
#   
#   # Make dataframe for predictions
#   newdf<-data.frame(island=levels(point.data.set$island))
#   
#   # Make the predictions
#   lambda <- predict(mod, newdata=newdf, type="lambda", appendData=TRUE)
#   phi <- predict(mod, newdata=newdf, type="phi", appendData=TRUE)
#   det <- predict(mod, newdata=newdf, type="det", appendData=TRUE)
#   
#   # Get ready to paste these on to the end of the output dataframes
#   spp <- rep(levels(birdcounts.long$spp)[i],dim(lambda)[1])
#   lambda <- cbind(spp,lambda)
#   phi <- cbind(spp,phi)
#   det <- cbind(spp,det)
#   
#   # Attach to ouput
#   lambda.island.out <- rbind(lambda.island.out,lambda)
#   phi.island.out <- rbind(phi.island.out,phi)
#   det.island.out <- rbind(det.island.out,det)
#   
#   print(warnings())
#   print(mod)
#   print(paste(i,"out of",length(levels(birdcounts.long$spp)),"done at", Sys.time(),sep=" "))
# }
# time2<-Sys.time()
# 
# write.csv(lambda.island.out,"lambda.island.out.csv")
# write.csv(phi.island.out,"phi.island.out.csv")
# write.csv(det.island.out,"det.island.out.csv")

lambda.island.out <- read.csv("./data/lambda.island.out.csv",row.names=1)
phi.island.out <- read.csv("./data/phi.island.out.csv",row.names=1)
det.island.out <- read.csv("./data/det.island.out.csv",row.names=1)

lambda.island.out$spp <- as.character(lambda.island.out$spp)
lambda.island.out$island <- as.character(lambda.island.out$island)





# spp.converter w/ all spp., symbols for figure
spp.converter<-c("apop"="mist",
                 "clma"="gowe",
                 "dima"="(bldr)",
                 "gaxa"="wtgd",
                 "gaga"="(chic)",
                 "mota"="timo",
                 "myru"="mihe",
                 "ptro"="mafd",
                 "rhru"="rufa",
                 "stbi"="(iscd)",
                 "toch"="cokf",
                 "zoco"="brwe$")#,
                 #"mela"="mime*",
                 #"coku"="rocr*",
                 #"gyal"="whte*")

# convert estimates to new species name
lambda.island.out$spp<-revalue(lambda.island.out$spp,spp.converter)
phi.island.out$spp<-revalue(phi.island.out$spp,spp.converter)
det.island.out$spp<-revalue(det.island.out$spp,spp.converter)

levels(birdcounts.long$spp)<-revalue(birdcounts.long$spp,spp.converter)
levels(lambda.island.out$spp)<-revalue(lambda.island.out$spp,spp.converter)
levels(birdcounts.long$spp)
#orderbird <- order(tapply(lambda.island.out$Predicted,lambda.island.out$spp,mean),decreasing=F) # not working
orderbird <- order(tapply(lambda.island.out$Predicted,lambda.island.out$spp,max),decreasing=T)
#orderbird<- c(3,8,14,11,10,6,7,1,12,9,2,15,13,5,4) # vector with preferred order

interval <- c(1,1,2.5)
x.vals <- c(1,1+cumsum(rep(interval,length(levels(birdcounts.long$spp)))))
x.vals <- x.vals[1:(length(x.vals)-1)]
x.vals <- matrix(x.vals,ncol=3,byrow=T)

pdf("abundance.pdf", width = 8, height = 6)
par(mfrow=c(1,1),pin=c(6.3,4))
plot(-10,
     xlim=c(min(x.vals)-1,max(x.vals)+1),
     ylim=c(min(lambda.island.out$lower),max(lambda.island.out$upper)),
     frame.plot=F,
     ylab="Density (birds / ha)",
     xlab="Species",
     las=1,
     xaxt="n",
     cex=2,
     pch=16)



for(i in orderbird) {#1:length(orderbird)) {
  sp.set <- subset(lambda.island.out,as.numeric(factor(lambda.island.out$spp))==i)#levels(birdcounts.long$spp)[orderbird[i]])
  rownames(sp.set) <- sp.set$island
  if(all(is.na(sp.set["Rota",]))) sp.set["Rota",] <- NA
  if(all(is.na(sp.set["Tinian",]))) sp.set["Tinian",] <- NA
  if(all(is.na(sp.set["Saipan",]))) sp.set["Saipan",] <- NA
  sp.set <- sp.set[c("Saipan","Tinian","Rota"),]
  sp.set[is.na(sp.set)] <- 0 # These are true zeros
  
  segments(x0=x.vals[which(orderbird == i),],y0=sp.set$lower,y1=sp.set$upper,
           lwd=10,
           lend="butt",
           col=c("grey30","grey60","grey90"))
  points(x.vals[which(orderbird == i),],sp.set[,"Predicted"],
         pch=c(21,22,23),
         bg="white")
  
}
legend("topleft",pch=c(21,22,23),
       legend=c("Saipan","Tinian","Rota"),
       bty="n")
axis(1, 
     at= x.vals[,2],
     labels = ifelse(levels(factor(lambda.island.out$spp))[orderbird] == "(iscd)",
                     "(phcd)",
                     levels(factor(lambda.island.out$spp))[orderbird]), # This is a clunky manual correction for the island collared dove being the Philippine Collared Dove
     las=2)

dev.off()

### cca

abund.long <- lambda.out[,c(1,2,6)]

head(abund.long)

abund.wide <- reshape(abund.long, v.names="Predicted",idvar="spp",timevar="point",direction="wide")
rownames(abund.wide) <- abund.wide$spp
abund.wide <- abund.wide[,c(2:dim(abund.wide)[2])]
colnames(abund.wide) <- levels(abund.long$point)
abund.wide[is.na(abund.wide)] <- 0

abund.wide <- abund.wide[row.names(fd.mat),]

abund.wide

#data(fd.mat) # fd.mat




### Make a Community Weighted Mean plot
cwm <- c("Diet.Fruit","Diet.Inv","Diet.Nect","Diet.Vert","Diet.Seed")
islands <- c("Saipan","Tinian","Rota")

interval <- c(1,1,2.5)
x.vals <- c(1,1+cumsum(rep(interval,5)))
x.vals <- x.vals[1:(length(x.vals)-1)]
x.vals <- matrix(x.vals,nrow=3,byrow=F)


# Make blank plot, then will fill in some data
pdf("cwm.pdf", width = 6, height = 4, useDingbats=FALSE)
par(mfrow=c(1,1),pin=c(3.5,3))
plot(x.vals,
     y=rep(-100,length(x.vals)),
     xlim = c(-1,max(x.vals)),
     ylim=c(0,60),
     frame.plot=F,
     ylab="Community Weighted Mean",
     xlab="",
     las=1,
     xaxt="n",
     cex=2,
     pch=16)

for(i in 1:length(cwm)) {
  
  row <- which(analysis.out$response==cwm[i])
  
  segments(x0=x.vals[,i],
           y0=as.numeric(analysis.out[row,c("saipan.ci.lo","tinian.ci.lo","rota.ci.lo")]),
           y1=as.numeric(analysis.out[row,c("saipan.ci.hi","tinian.ci.hi","rota.ci.hi")]),
           lwd=10,
           col=c("grey30","grey60","grey90"),
           lend="butt")
  
  points(x.vals[,i],as.numeric(analysis.out[row,c("saipan","tinian","rota")]),
         pch=c(21:23),
         bg="white")
  text(x.vals[,i], 
       as.numeric(analysis.out[row,c("saipan.ci.hi","tinian.ci.hi","rota.ci.hi")]) + 2, 
       analysis.out[row,13:15])
}

axis(1, at = x.vals[2,], labels=gsub("Diet.","",cwm))

legend("topright",pch=c(21:23),
       legend=islands,
       bty="n")
legend("topleft", "A", bty = "n")
dev.off()


# make cca plot
colnames(abund.wide) <- c("T","T","T","S","S","S","R","R","R","R","R","R","T","T","T","T","T","T","S","S","S","S","S","S","R","R","R")
cols <- c("grey40","grey40","grey40","grey60","grey60","grey60","grey90","grey90","grey90","grey90","grey90","grey90","grey40","grey40","grey40","grey40","grey40","grey40","grey60","grey60","grey60","grey60","grey60","grey60","grey90","grey90","grey90")
fd.mat$num.foraging <- as.numeric(as.factor(fd.mat$ForagingLocation))
vare.cca <- cca(abund.wide,fd.mat[,c(1:6,8)])#[,c(1:5)])
vare.cca
par(mfrow=c(1,1),pin=c(5,4))
labls <- c("invert","vert","fruit","nectar","seed","mass")

pdf("cca.pdf", width = 6, height = 4)
par(mfrow=c(1,1),pin=c(3.5,3))
plot(vare.cca,type="none",scaling="sites", las = 1)
text(vare.cca,display="species",col=cols,cex=0.75,font=2)
text(vare.cca,display="sites",cex=0.75,col=c("grey25"))
text(vare.cca,display="bp",cex=1,labels = labls, scaling="sites")
legend("topleft", "B", bty = "n")
dev.off()


#plot outline of islands
par(mfrow=c(1,1),pin=c(1.5,2.5))
map <- map_data("worldHires", xlim=c(130,150), ylim=c(12,16))
ggplot() + coord_map()+
  geom_path(data=map, aes(x=long, y=lat, group=group)) +
  theme_bw() +
  theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank()) +
  xlab("Longitude") +
  ylab("Latitude") +
  guides(fill=guide_legend(title=NULL))

#plot pacific
map <- map_data("world", xlim=c(100,165), ylim=c(-12,25))
ggplot() + coord_map()+
  geom_path(data=map, aes(x=long, y=lat, group=group)) +
  theme_bw() +
  theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank()) +
  xlab("Longitude") +
  ylab("Latitude") +
  guides(fill=guide_legend(title=NULL))

