### Drought timeseries bar plot function

SPEI_annual_bar <- function(data, period.box=T, title){
  ggplot(data = data, aes(x=as.numeric(as.character(Year)), y=SPEI,fill = col)) + 
    {if(period.box==T) geom_rect(xmin=Yr-Range/2, xmax=Yr+Range/2, ymin=-Inf, ymax=Inf, alpha=0.1, fill="darkgray", col="darkgray")} +
    geom_bar(stat="identity",aes(fill=col),col="black") + 
    geom_hline(yintercept=-.5,linetype=2,colour="black",size=1) +
    scale_fill_manual(name="",values =c("turquoise2","orange1")) +
    labs(title = title, 
         x = "Date", y = "SPEI") +
    guides(color=guide_legend(override.aes = list(size=7))) + PlotTheme
}

############################### FORMAT DATAFRAMES  ############################################
MonthlyWB <- read.csv(paste0(TableDir,"WB-Monthly.csv")) %>% 
  left_join(WB_GCMs,by="GCM") %>% 
  mutate(CF = factor(CF, levels=c("Historical",CFs)),
         Date = as.POSIXct(paste(substr(yrmon,1,4),substr(yrmon,5,6),"1",sep="-"),format="%Y-%m-%d"),
         Year = format(Date, "%Y")) %>% 
  arrange(Date)
  


M1 <- list()
for (i in 1:length(CFs)){
  M = MonthlyWB %>% filter(CF %in% c("Historical",CFs[i])) %>% 
    complete(Date = seq(min(Date), max(Date), by = "1 month"), 
             fill = list(value = NA)) 
  
  tp<-ts(M$sum_p.mm,frequency=12,start=c(SPEI_start,1)); tp[is.na(tp)]<-0
  tpet<-ts(M$sum_pet.mm,frequency=12,start=c(SPEI_start,1)); tpet[is.na(tpet)]<-0
  SPEI<-spei(tp-tpet,SPEI_per,ref.start=c(SPEI_start,1),ref.end=c(SPEI_end,12))
  M$SPEI = SPEI$fitted[1:length(SPEI$fitted)]
  M1[[i]]<-M %>% drop_na()
}
all2<- ldply(M1, data.frame) #convert back to df
all2$SPEI[which(is.infinite(all2$SPEI))]<- -5 #getting some -Inf values that are large jumps, temp fix

# 
# all3<-subset(all2,Month==9) #Because we aggregated drought years as only applying to growing season
#                             # If you are doing for place where winter drought would be important, use following line
all3<-aggregate(cbind(sum_pet.mm,SPEI)~Year+CF,all2,mean)

###################################### PLOT ANNUAL TIME-SERIES #################################################

# MACA prep dataframe
all3$col[all3$SPEI>=0]<-"above average"
all3$col[all3$SPEI<0]<-"below average"
all3$col<-factor(all3$col, levels=c("above average","below average"))
all3$Year<-as.numeric(all3$Year)

# CF 
CF1<-subset(all3, CF %in% c("Historical",CFs[1]) )

SPEI_annual_bar(subset(CF1,Year>=Yr-Range/2 & Year<=Yr+Range/2), period.box=T,
                title=paste("SPEI values for", CFs[1], "climate future", sep = " " )) 
ggsave("SPEI-CF1-Annual-bar.png", path = FigDir, width = PlotWidth, height = PlotHeight)

SPEI_annual_bar(CF1, period.box=T,
                title=paste("SPEI values for", CFs[1], "climate future", sep = " " )) 
ggsave("SPEI-CF1-gridmet-Annual-bar.png", path = FigDir, width = PlotWidth, height = PlotHeight)

# CF 2
CF2<-subset(all3, CF %in% c("Historical",CFs[2]) )

SPEI_annual_bar(subset(CF2,Year>=Yr-Range/2 & Year<=Yr+Range/2), period.box=T,
                title=paste("SPEI values for", CFs[2], "climate future", sep = " " )) 
ggsave("SPEI-CF2-Annual-bar.png", path = FigDir, width = PlotWidth, height = PlotHeight)

SPEI_annual_bar(CF2, period.box=T,
                title=paste("SPEI values for", CFs[2], "climate future", sep = " " )) 
ggsave("SPEI-CF2-gridmet-Annual-bar.png", path = FigDir, width = PlotWidth, height = PlotHeight)


# Split into periods
drt3<-subset(all3, Year <=2012)
min(drt3$SPEI)

Future.drt<-subset(all3, Year >= Yr-Range/2 & Year <= Yr+Range/2)
min(Future.drt$SPEI)

# Calculate drought characteristics
drt3$Drought=0
drt3$Drought[which(drt3$SPEI < truncation)] <- 1

# Drought Duration calculation
# 1 Create var for beginnign drought and var for end drought, then count months between
head(drt3)

# Create count of years within CF
length(drt3$Year)
drt3$count<-seq(1, length(drt3$Year),1) 

drt3$length<-0
drt3$length <- drt3$Drought * unlist(lapply(rle(drt3$Drought)$lengths, seq_len))
mean(drt3$length[drt3$length>0])

# To get duration, now just remove those that are not droughts and do calculations on length

# Give each drought period an ID
D<-which(drt3$length==1)
HistoricalDrought<-data.frame()
HistoricalDrought<-setNames(data.frame(matrix(ncol=10,nrow=length(D))),c("DID","Start","End","Year","per","CF","duration","severity","peak","freq"))
HistoricalDrought$Start = Sys.time(); HistoricalDrought$End = Sys.time()
HistoricalDrought$per<-as.factor("H")


# Calculate variables for each drought period
for (i in 1:length(D)){
  HistoricalDrought$DID[i]<-i
  HistoricalDrought$Start[i]<-strptime(drt3$Date[D[i]],format="%Y-%m-%d",tz="MST")
  HistoricalDrought$Year[i]<-drt3$Year[D[i]]
}

ND<- which((drt3$length == 0) * unlist(lapply(rle(drt3$length)$lengths, seq_len)) == 1)
if(ND[1]==1) ND<-ND[2:length(ND)]
if(drt3$Drought[length(drt3$Drought)]==1) ND[length(ND)+1]<-length(drt3$length)

###### !!!!!!!!!!! 
# If last row in drought df is a drought period - use next line of code. Otherwies proceed.
# ND[length(ND)+1]<-length(drt3$length) #had to add this step because last drought went until end of df so no end in ND

#Duration # months SPEI < truncation; Severity # Sum(SPEI) when SPEI < truncation; Peak # min(SPEI) when SPEI < truncation

for (i in 1:length(ND)){
  HistoricalDrought$End[i]<-strptime(drt3$Date[ND[i]],format="%Y-%m-%d",tz="MST")
  HistoricalDrought$duration[i]<-drt3$length[ND[i]-1]
  HistoricalDrought$severity[i]<-sum(drt3$SPEI[D[i]:(ND[i]-1)])
  HistoricalDrought$peak[i]<-min(drt3$SPEI[D[i]:(ND[i]-1)])
}

## Freq
  d<-which(drt3$length==1)
  nd<-which((drt3$length == 0) * unlist(lapply(rle(drt3$length)$lengths, seq_len)) == 1)
  if(length(nd)>length(d)) {nd=nd[2:length(nd)]}
  for (j in 1:length(d)){
    HistoricalDrought$freq[which(HistoricalDrought$Year==drt3$Year[d[j]])] <-
      drt3$count[d[j+1]]-drt3$count[nd[j]]
  }

####### Future
# Calculate drought characteristics
Future.drt$Drought=0
Future.drt$Drought[which(Future.drt$SPEI < truncation)] <- 1

# Drought Duration calculation
# 1 Create var for beginnign drought and var for end drought, then count months between
head(Future.drt)

# Create count of months within CF
length(Future.drt$CF)/length(unique(Future.drt$CF))
Future.drt$count<-rep(seq(1, length(Future.drt$CF)/length(unique(Future.drt$CF)), 
                       1),length(unique(Future.drt$CF))) # repeat # of CFs 

Future.drt$length<-0
Future.drt$length <- Future.drt$Drought * unlist(lapply(rle(Future.drt$Drought)$lengths, seq_len))
mean(Future.drt$length[Future.drt$length>0])

# To get duration, now just remove those that are not droughts and do calculations on length

# Give each drought period an ID
D<-which(Future.drt$length==1)
FutureDrought<-data.frame()
FutureDrought<-setNames(data.frame(matrix(ncol=10,nrow=length(D))),c("DID","Start","End","Year","per","CF","duration","severity","peak","freq"))
FutureDrought$Start = Sys.time(); FutureDrought$End = Sys.time()
FutureDrought$per<-as.factor("F")


# Calculate variables for each drought period
for (i in 1:length(D)){
  FutureDrought$DID[i]<-i
  FutureDrought$Start[i]<-strptime(Future.drt$Date[D[i]],format="%Y-%m-%d",tz="MST")
  FutureDrought$Year[i]<-Future.drt$Year[D[i]]
}

ND<- which((Future.drt$length == 0) * unlist(lapply(rle(Future.drt$length)$lengths, seq_len)) == 1)
if(ND[1]==1) ND<-ND[2:length(ND)]
if(Future.drt$Drought[length(Future.drt$Drought)]==1) ND[length(ND)+1]<-length(Future.drt$length)

#Duration # months SPEI < truncation; Severity # Sum(SPEI) when SPEI < truncation; Peak # min(SPEI) when SPEI < truncation

for (i in 1:length(ND)){
  FutureDrought$CF[i]<-as.character(Future.drt$CF[D[i]])
  FutureDrought$End[i]<-strptime(Future.drt$Date[ND[i]],format="%Y-%m-%d",tz="MST")
  FutureDrought$duration[i]<-Future.drt$length[ND[i]-1]
  FutureDrought$severity[i]<-sum(Future.drt$SPEI[D[i]:(ND[i]-1)])
  FutureDrought$peak[i]<-min(Future.drt$SPEI[D[i]:(ND[i]-1)])
}
if(length(unique(FutureDrought$CF)) == 1) {FD <- FutureDrought %>% filter(row_number()==1) %>%
  mutate(Year = 9999, CF = CFs[!(CFs %in% unique(FutureDrought$CF))],
         duration = 0, severity = 0, peak = 0, freq = 0)
CFs[!(CFs %in% unique(FutureDrought$CF))]
FutureDrought = rbind(FutureDrought, FD)
rm(FD)}  

FutureDrought$CF<-as.factor(FutureDrought$CF)


## Freq

CF.split<-split(Future.drt,Future.drt$CF)
for (i in 1:length(CF.split)){
  name=as.character(unique(CF.split[[i]]$CF))
  d<-which(CF.split[[i]]$length==1)
  nd<-which((CF.split[[i]]$length == 0) * unlist(lapply(rle(CF.split[[i]]$length)$lengths, seq_len)) == 1)
  if(length(nd)>length(d)) {nd=nd[2:length(nd)]}
  for (j in 1:length(d)){
    FutureDrought$freq[which(FutureDrought$CF==name & FutureDrought$Year==CF.split[[i]]$Year[d[j]])] <-
      CF.split[[i]]$count[d[j+1]]-CF.split[[i]]$count[nd[j]]
  }
}
HistoricalDrought$freq[is.na(HistoricalDrought$freq)] <- 0
FutureDrought$freq[is.na(FutureDrought$freq)] <- 0

head(HistoricalDrought)
head(FutureDrought)
Drought<-rbind(HistoricalDrought,FutureDrought)
write.csv(Drought,paste0(TableDir,"Drt.all.csv"),row.names=FALSE)  # csv with all drought events

Hist_char<-setNames(data.frame(matrix(ncol=6,nrow=1)),c("CF","per","Duration","Severity","Intensity","Frequency"))
Hist_char$CF<-"Historical"
Hist_char$per<-"H"
Hist_char$Frequency<-mean(HistoricalDrought$freq,na.rm=TRUE)
Hist_char$Duration<-mean(HistoricalDrought$duration)
Hist_char$Severity<-mean(HistoricalDrought$severity)
Hist_char$Intensity<-mean(HistoricalDrought$peak)


Drought_char<-setNames(data.frame(matrix(ncol=6,nrow=length(levels(FutureDrought$CF)))),c("CF","per","Duration","Severity","Intensity","Frequency"))
Drought_char$CF<-levels(FutureDrought$CF)
Drought_char$per<-"F"
for (i in 1:length(Drought_char$CF)){
  name<-Drought_char$CF[i]
  Drought_char$Frequency[i]<-mean(FutureDrought$freq[which(FutureDrought$CF == name)],na.rm=TRUE)
  Drought_char$Duration[i]<-mean(FutureDrought$duration[which(FutureDrought$CF == name)])
  Drought_char$Severity[i]<-mean(FutureDrought$severity[which(FutureDrought$CF == name)])
  Drought_char$Intensity[i]<-mean(FutureDrought$peak[which(FutureDrought$CF == name)])
  }

Drought_char<-rbind(Hist_char,Drought_char) 

# csv for averages for each CF for hist and future periods
write.csv(Drought_char,paste0(TableDir,"Drought_characteristics.csv"),row.names=FALSE)


########################################### BAR PLOTS ###############################################
#Drought duration barplot
Drought_all = Drought_char
Drought_all$CF = factor(Drought_all$CF, levels = c("Historical",CFs))

#Drought duration barplot
var_bar_plot(Drought_all,"Duration", colors3, "Average Drought Duration", "Years")
ggsave("DroughtDuration-Bar.png", path = FigDir, height=PlotHeight, width=PlotWidth)

#Drought severity barplot
var_bar_plot(Drought_all,"Severity", colors3, "Average Drought Severity", 
             "Severity (Intensity * Duration)") + coord_cartesian(ylim = c(0, min(Drought_all$Severity)))
ggsave("DroughtSeverity-Bar.png", path = FigDir, height=PlotHeight, width=PlotWidth)

#Drought intensity barplot
var_bar_plot(Drought_all,"Intensity", colors3, "Average Drought Intensity", 
             "Intensity (Minimum SPEI values)") + coord_cartesian(ylim = c(0, min(Drought_all$Intensity)))
ggsave("DroughtIntensity-Bar.png", path = FigDir, height=PlotHeight, width=PlotWidth)

#Drought-free interval barplot
var_bar_plot(Drought_all,"Frequency", colors3, "Average Drought-Free Interval", 
             "Years")
ggsave("DroughtFrequency-Bar.png", path = FigDir, height=PlotHeight, width=PlotWidth)


####################################### REPORT FIGURES ##############################################
# Option 1
a <- SPEI_annual_bar(CF1, period.box=T,
                title=CFs[1]) + coord_cartesian(ylim = c(min(all3$SPEI), max(all3$SPEI)))
b <- SPEI_annual_bar(CF2, period.box=T,
                     title=CFs[2]) +  coord_cartesian(ylim = c(min(all3$SPEI), max(all3$SPEI)))

c <- var_bar_plot(Drought_all,"Duration", colors3, "Duration", "Years")
d <- var_bar_plot(Drought_all,"Frequency", colors3, "Return interval", 
             "Years")
e<- var_bar_plot(Drought_all,"Severity", colors3, "Severity", 
                  "Severity (Intensity * Duration)")+ coord_cartesian(ylim = c(0, min(Drought_all$Severity)))

spei.time <- grid_arrange_shared_legend(a + rremove("ylab") + rremove("x.text"),b +  rremove("ylab"),
                                        nrow=2,ncol=1,position="bottom")

spei.time <- annotate_figure(spei.time, left = textGrob("SPEI", rot = 90, vjust = 1, gp = gpar(cex = 2)))

drt.char <- grid.arrange(c+rremove("x.text"),d+rremove("x.text"),e,nrow=3,
                         top = textGrob("Average drought \ncharacteristics",gp=gpar(fontface="bold", col="black", fontsize=26,hjust=0.5)))

g <- grid.arrange(spei.time, drt.char,ncol = 2, clip = FALSE)
ggsave("DroughtCharacteristics-1-Panel.png",g, path = FigDir, height=PanelHeight, width=PanelWidth)


# Option 2
c <- c+ theme(legend.title=element_text(size=24),legend.text=element_text(size=22),legend.position = "bottom")
d <- d+ theme(legend.title=element_text(size=24),legend.text=element_text(size=22),legend.position = "bottom")
e <- e+ theme(legend.title=element_text(size=24),legend.text=element_text(size=22),legend.position = "bottom")

drt.char <-grid_arrange_shared_legend(c+ rremove("x.text"),d+ rremove("x.text"),e+ rremove("x.text"),
                                      ncol=3,nrow=1,position="bottom",
                                      top = textGrob("Average drought characteristics",gp=gpar(fontface="bold", col="black", fontsize=26,hjust=0.5)))
g <- grid.arrange(spei.time, drt.char,nrow=2,ncol = 1, clip = FALSE)
ggsave("DroughtCharacteristics-2-Panel.png",g, path = FigDir, height=PanelHeight, width=PanelWidth)                      
