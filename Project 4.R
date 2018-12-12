### Lori Kim
## Projct 4

#setwd("C:/Users/lkim016/Desktop")

# get library packages
library(dplyr)
library(tidyr)
library(corrplot)
library(ISLR)
library(leaps)

# CSV variables
properties1 <- read.csv('properties_2016.csv')
transactions <- read.csv('train_2016_v2.csv')

properties = as.data.frame(properties1)
# colnames(properties) = colnames(properties1)

#### Clean up all the data
# Rename original 58 variable names
# FunctionX(dataA) is the same as dataA %>% functionX
properties <- properties %>% rename(
  id_parcel = parcelid,
  build_year = yearbuilt,
  area_basement = basementsqft,
  area_patio = yardbuildingsqft17,
  area_shed = yardbuildingsqft26, 
  area_pool = poolsizesum,  
  area_lot = lotsizesquarefeet, 
  area_garage = garagetotalsqft,
  area_firstfloor_finished = finishedfloor1squarefeet,
  area_total_calc = calculatedfinishedsquarefeet,
  area_base = finishedsquarefeet6,
  area_live_finished = finishedsquarefeet12,
  area_liveperi_finished = finishedsquarefeet13,
  area_total_finished = finishedsquarefeet15,  
  area_unknown = finishedsquarefeet50,
  num_unit = unitcnt, 
  num_story = numberofstories,  
  num_room = roomcnt,
  num_bathroom = bathroomcnt,
  num_bedroom = bedroomcnt,
  num_bathroom_calc = calculatedbathnbr,
  num_bath = fullbathcnt,  
  num_75_bath = threequarterbathnbr, 
  num_fireplace = fireplacecnt,
  num_pool = poolcnt,  
  num_garage = garagecarcnt,  
  region_county = regionidcounty,
  region_city = regionidcity,
  region_zip = regionidzip,
  region_neighbor = regionidneighborhood,  
  tax_total = taxvaluedollarcnt,
  tax_building = structuretaxvaluedollarcnt,
  tax_land = landtaxvaluedollarcnt,
  tax_property = taxamount,
  tax_year = assessmentyear,
  tax_delinquency = taxdelinquencyflag,
  tax_delinquency_year = taxdelinquencyyear,
  zoning_property = propertyzoningdesc,
  zoning_landuse = propertylandusetypeid,
  zoning_landuse_county = propertycountylandusecode,
  flag_fireplace = fireplaceflag, 
  flag_tub = hashottuborspa,
  quality = buildingqualitytypeid,
  framing = buildingclasstypeid,
  material = typeconstructiontypeid,
  deck = decktypeid,
  story = storytypeid,
  heating = heatingorsystemtypeid,
  aircon = airconditioningtypeid,
  architectural_style = architecturalstyletypeid
)

transactions <- transactions %>% rename(
  id_parcel = parcelid,
  date = transactiondate
)

# Convert dummary variables (Y and N) to (1 and 0)
properties <- properties %>% 
  mutate(tax_delinquency = ifelse(tax_delinquency=="Y",1,0),
         flag_fireplace = ifelse(flag_fireplace=="Y",1,0),
         flag_tub = ifelse(flag_tub=="Y",1,0))

# Adding absolute logerror col
transactions <- transactions %>% mutate(abs_logerror = abs(logerror))

#### Start missing value calculations
# Missing values management
missing_values <- properties %>% summarize_all(funs(sum(is.na(.))/n()))

missing_values <- gather(missing_values, key="feature", value="missing_pct") # change missing_values data frame to columns

good_features <- filter(missing_values, missing_pct < 0.25) # only get the variables that have missing_pct < 0.25

cor_tmp <- transactions %>% left_join(properties, by = "id_parcel")

cor_tmp = cor_tmp %>% select(good_features$feature, logerror, abs_logerror,
                             -id_parcel, -fips, -latitude, -longitude, -zoning_landuse_county, -zoning_property, -rawcensustractandblock,
                             -region_city, -region_zip, -censustractandblock, -tax_year, -tax_building, -tax_land, -flag_tub, -flag_fireplace)

# Get rid of highly correlated variables
cor_tmp = cor_tmp %>% select(-one_of(c("num_bath", "num_bathroom", "area_live_finished", "tax_total")))

# Analyzing the correlation
# Remove highly correlated variables (correlation > 0.95)
# don't need flag_tub / flag_fireplace
corr = cor(cor_tmp, use="complete.obs")
corrplot(corr,type="lower")

# change 2 variables from int to factor
cor_tmp$zoning_landuse = factor(cor_tmp$zoning_landuse) # we convert these to factor to show each of the levels and their correlation
cor_tmp$region_county = factor(cor_tmp$region_county)

str(cor_tmp)
levels(cor_tmp$zoning_landuse)

# run the regression for logerror 
lm.log = lm(logerror ~ . , data = cor_tmp) #* why does the regression take out level 31 and 47 from the summary
summary(lm.log)
#* the high t value of the area_total_calc (9.261) shows that zillow's forecast model
# tends to overshoot when the area_total_calc is high which means the zillow's estimate of the
# property price overshoots, while the tax_property is t value - 13.827 which means when the tax_property is low
# then zillow's estimate also overshoots


# regsubsets
regfit.full=regsubsets(logerror ~., data = cor_tmp)
summary(regfit.full)
logsum = summary(regfit.full)
names(logsum)

a = which.max(logsum$adjr2)  # identify the location of the maximum point of a vector
a
plot(logsum$cp,xlab="Number of Variables",ylab="Cp",type='l')
points(a,logsum$adjr2[a], col="red",cex=2,pch=20)
b = which.min(logsum$cp) # Cp is AIC
b
points(b,logsum$cp[b],col="blue",cex=2,pch=20)
c = which.min(logsum$bic)
c
plot(logsum$bic,xlab="Number of Variables",ylab="BIC",type='l')
points(c,logsum$bic[c],col="green",cex=2,pch=20)

# run the regression for abs logerror
lm.abs = lm(abs_logerror ~ . , data = cor_tmp)
summary(lm.abs)
abline(lm(abs_logerror ~ . , data = cor_tmp), col="red")

# The logerror regression has many more predictor variables that are statistically significant while the Adjusted R-squared is quite low.
# Whereas, the abs_logerror regression has variables such as, num_bedroom, area_total_calc, build_year,tax_property, tax_delinquency, and logerror with higher statistical significance.
# Also, the Adjusted R-squared is 0.098 which is slightly higher than the logerror regression. I would inform Zillow that the
# model for logerror is the better model because of it's low Adjusted R-squared and it has many variables statistically significant in correlating with logerror.

