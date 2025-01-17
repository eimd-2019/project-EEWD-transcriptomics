rm(list=ls())

#setwd("output/04-edgeR/")

library(edgeR)

#look at Section 3.2

# making a matrix of factors called "targets",Treat=Pathogen, Heat=Temp
targets <-readTargets("targets.txt")
targets

# setting groups equal to time differences 
group <- targets$Treat_Heat
group <- as.factor(group)
group

# importing raw data
rawdata <- read.delim("../03-assembly-annotation/c-uniprot/nonZostera-blast-annot-withGeneID-noIsoforms-geneCounts.tab", header=FALSE)
head(rawdata)
colnames(rawdata)<- c("GeneID", "Accession", "Isoform", "E-value", "ProteinN", "GO_BP", "GO_CC", "GO_MF", "GO", "Status", "Organism", "S_10B", "S_9A", "S_13A", "S_42A", "S_46B", "S_47B", "S_48B", "S_2A", "S_2B", "S_7B", "S_8B", "S_33A", "S_36B", "S_38A", "S_40A")
row.names(rawdata)<-rawdata$GeneID
head(rawdata)

#2.5
# making my DGE list
y <- DGEList(counts=rawdata[,12:26],group=group)
head(y$counts)


#2.6
# filtering out lowly expressed genes; since the smallest group size is four, we keeping genes with at least one count per million in at least four samples
keep <- rowSums(cpm(y)>1) >= 3
y <- y[keep,]
dim(y) 

#keeping 1,281 genes in 15 libraries from nonZostera file

#recompute the library sizes:
y$samples$lib.size <- colSums(y$counts)

#2.7
#calculating normalization factors
y <- calcNormFactors(y)
y$samples 
# looks good
n <- y$samples$lib.size

# examining sample for outliers
#4.15
points <- c(0,1,2,3)
colors <- (rep(c("blue","red"),2))
plotMDS(y, col=colors[group], pch=points[group])  
legend ("top", legend=levels(group), pch=points, col=colors, ncol=2)

#3.23
design <-model.matrix(~0+group)
colnames(design) <- levels(group)
design

#2.10
y <- estimateGLMCommonDisp(y, design, verbose=TRUE)
y <- estimateGLMTrendedDisp(y,design)
y <- estimateGLMTagwiseDisp(y,design)
plotBCV(y)

#3.25
fit <- glmQLFit(y, design)
design
colnames(fit)

#Estimating dispersion (pg.54)
y <- estimateDisp(y, design, robust=TRUE)

y$common.dispersion
#[1] 1.861212
plotBCV(y)
#page48, coefficient of biological variation=1.36


#Set up following #3.31 (from older leve, different order)
#MEE contrasts: What genes are DE in shoots exposed to laby vs controls? Make 4 contrasts and look for genes DE in all 4
my.contrasts <-makeContrasts(
  EXPH.CONH=EXP_HOT-CON_HOT, EXPH.CONC=EXP_HOT-CON_COLD, EXPC.CONH=EXP_COLD-CON_HOT, EXPC.CONC=EXP_COLD-CON_COLD, levels=design)

qlf.EXPH.CONH <- glmQLFTest(fit, contrast=my.contrasts[,"EXPH.CONH"])
topTags(qlf.EXPH.CONH)
qlf.EXPH.CONC <- glmQLFTest(fit, contrast=my.contrasts[,"EXPH.CONC"])
topTags(qlf.EXPH.CONC)
qlf.EXPC.CONH <- glmQLFTest(fit, contrast=my.contrasts[,"EXPC.CONH"])
topTags(qlf.EXPC.CONH)
qlf.EXPC.CONC <- glmQLFTest(fit, contrast=my.contrasts[,"EXPC.CONC"])
topTags(qlf.EXPC.CONC)

summary(decideTests(qlf.EXPH.CONH))
#UP: 56, DOWN:2
summary(decideTests(qlf.EXPH.CONC))
#UP: 56, DOWN: 3
summary(decideTests(qlf.EXPC.CONH))
#UP: 61, DOWN: 22
summary(decideTests(qlf.EXPC.CONC))
#UP: 57, DOWN: 10

plotMD(qlf.EXPH.CONH)
abline(h=c(-2,2), col="green")

plotMD(qlf.EXPH.CONC)
abline(h=c(-2,2), col="green")

plotMD(qlf.EXPC.CONH)
abline(h=c(-2,2), col="green")

plotMD(qlf.EXPC.CONC)
abline(h=c(-2,2), col="green")


#MEE contrasts: what genes are DE between laby exposed shoots hot and cold treatments?
my.contrasts <-makeContrasts(
  EXPH.EXPC=EXP_HOT-EXP_COLD, levels=design)
qlf.EXPH.EXPC <- glmQLFTest(fit, contrast=my.contrasts[,"EXPH.EXPC"])
topTags(qlf.EXPH.EXPC)

summary(decideTests(qlf.EXPH.EXPC))
#UP: 0, DOWN: 0


#MEEcontrasts: what genes are DE between hot and cold control shoots? 

my.contrasts <-makeContrasts(
  CONH.CONC=CON_HOT-CON_COLD, levels=design)
qlf.CONH.CONC <- glmQLFTest(fit, contrast=my.contrasts[,"CONH.CONC"])
topTags(qlf.CONH.CONC)

summary(decideTests(qlf.CONH.CONC))
#0

#MEEcontrasts: What genes are DE between the exposed (hot and cold) and control (hot and cold) shoots? 
my.contrasts4 <-makeContrasts(
  EXP.CON=(EXP_HOT+EXP_COLD)-(CON_HOT+CON_COLD), levels=design)
 qlf.EXP.CON <- glmQLFTest(fit, contrast=my.contrasts4[,"EXP.CON"])
topTags(qlf.EXP.CON)

summary(decideTests(qlf.EXP.CON))
#UP: 79, DOWN: 21

#looking at the counts per million
top <- rownames(topTags(qlf.EXP.CON))
cpm(y)[top,]

#logCPM 1.2 #####NEW######

logCPM <-cpm(y, prior.count = 2, log=TRUE)
head(logCPM)
write.table (logCPM, "EXP.CON.nZostera.logCPM.txt", sep="\t")


#MEE Graphs of 3 more contrasts listed above:

plotMD(qlf.EXPH.EXPC)
abline(h=c(-2,2), col="black")

plotMD(qlf.CONH.CONC)
abline(h=c(-2,2), col="black")

plotMD(qlf.EXP.CON)
abline(h=c(-1,1), col="blue")
abline(h=c(-5,5), col="green")
abline(h=c(-10,10), col="purple")


#Writetable
#Inf=infinite number so all samples
top <-topTags(qlf.EXP.CON, n=Inf)
write.table (top, "EXP.CON.NonZostera.all.txt", sep="\t")

#Smaller list
#FDR correct p-values, 0.05
out <- topTags(qlf.EXP.CON, n=Inf, adjust.method="BH")
keep <- out$table$FDR <= 0.05 
out[keep,]

#Merge with original data
nonZostera.DE.EXP.CON.FDR <- as.data.frame(out[keep,]) #Save as a new dataframe
nonZostera.DE.EXP.CON.FDR$GeneID <- row.names(nonZostera.DE.EXP.CON.FDR) #Save row names as GeneID column
head(nonZostera.DE.EXP.CON.FDR)
nonZostera.DE.EXP.CON.FDR.annot <- merge(x = nonZostera.DE.EXP.CON.FDR, y = rawdata, by = "GeneID")
head(nonZostera.DE.EXP.CON.FDR.annot)

write.table(nonZostera.DE.EXP.CON.FDR.annot, file="DE.EXP.CON.FDR.nZ.Annot.txt", col.names = NA, quote=FALSE, sep = "\t")

#Merge with logCPM #####NEW######
#log2 table with diff expressed
logCPM = read.delim("EXP.CON.nZostera.logCPM.txt", header=TRUE)
nZostera = read.delim("DE.EXP.CON.FDR.nZ.Annot.M.txt", header=TRUE)
nZostera.DE.EXP.CON.FDR.annot.logCPM =merge(x=nZostera, y=logCPM, by = "GeneID")
head(nZostera.DE.EXP.CON.FDR.annot.logCPM)
write.table (nZostera.DE.EXP.CON.FDR.annot.logCPM, "nZostera.logCPM.txt", sep="\t")









