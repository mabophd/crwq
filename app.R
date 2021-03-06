#Data Cleaning and Analysis
library(gdata)
#Importing Excel
df = read.xls (("https://github.com/mabophd/crwq/files/5653743/CountryData.xlsx"), sheet = 1, header = TRUE)

#Removing blank rows generated
df <- df[c(1:21)]

# Renaming the vairbles to be human readable.
names(df)[3:21]<- c("ForeignInvestment", "ElectricityAccess", "RenewableEnergy", "CO2Emission", "Inflation", "MobileSubscriptions", "InternetUse", "Exports", "Imports", "GDP", "MortalityMale", "MortalityFemale", "BirthRate", "DeathRate", "MortalityInfant", "LifeExpectancy", "FertilityRate", "PopulationGrowth", "UrbanPopulation")

# Looking at null values
#we check for NA's in rows
null_rows = apply(df, 1, function(x) sum(is.na(x)))

#we add the country names
row_nulls = data.frame(df$CountryName,null_rows)

#we select where not 0
row_nulls[as.numeric(row_nulls[,2])>0,]

#we check for nulls in columns
apply(df, 2, function(x) sum(is.na(x)))

# Setting seed so out results are imputation results are reprodcuible
set.seed(0)

require(caret)
#we impute missing values with a random forest
imputation_model = preProcess(x = df[,-c(1,2)],method = "bagImpute")
imputated_data = predict(object = imputation_model,newdata=df[,-c(1,2)])

# Adding country names to the rows
rownames(imputated_data)<-df[,2] 

#Checking out this fresh imputated data
head(imputated_data)
str(imputated_data)

#we check for nulls in imputed data, success there are none :D
apply(imputated_data, 2, function(x) sum(is.na(x)))


#################################################################################

# PCA for our Biplot. Note scale =TRUE as we need to standardize our data
pca.out<-prcomp(imputated_data,scale=TRUE)
pca.out
biplot(pca.out,scale = 0, cex=0.75)

# Creating a datatable to store and plot the
# No of Principal Components vs Cumulative Variance Explained
vexplained <- as.data.frame(pca.out$sdev^2/sum(pca.out$sdev^2))
vexplained <- cbind(c(1:19),vexplained,cumsum(vexplained[,1]))
colnames(vexplained) <- c("No_of_Principal_Components","Individual_Variance_Explained",
                          "Cumulative_Variance_Explained")

# Table showing the amount of variance explained by the principle components
vexplained

# load required package
library(factoextra) 
# contributions 
plot1 <- fviz_contrib(pca.out, choice="var", axes = 1, top = 19)
plot2 <- fviz_contrib(pca.out, choice="var", axes = 2, top = 19, color = "lightgrey")

library(gridExtra)
grid.arrange(plot1, plot2, nrow=2)

# Scaling our data
scaled_data = scale(imputated_data)

# Visualising the dissimalirty matrix. Viually shows distinct clusters. 
fviz_dist(dist(scaled_data), show_labels = FALSE)+ labs(title = "Euclidean distance")

#plotting just 20 countires :) 
randomplot <- sample(1:183, 20)
mydata.sample<- scaled_data[randomplot,]
fviz_dist(dist(mydata.sample), show_labels = TRUE)+ labs(title = "Euclidean distance")

# Choosing the number of k
library(NbClust)
res<- NbClust(scaled_data, distance = "euclidean", min.nc=2, max.nc=10, 
              method = "kmeans", index = "all")  

# Can access details of the tests here if you like
res

############################################################


# K-means clustering
km.res <- kmeans(scaled_data, 3, nstart = 50)

# Cluster visualisation
fviz_cluster(km.res, 
             data = scaled_data,
             palette = c("#2E9FDF", "#00AFBB", "#E7B800"), 
             ellipse.type = "euclid", 
             star.plot = TRUE, # Add segments from centroids to items
             repel = TRUE, # Avoid label overplotting (slow)
             ggtheme = theme_minimal()
)

# Finding the averages for each cluster
aggregate(imputated_data, by=list(cluster=km.res$cluster), mean)

#Required libraries for world map plotting
library(rworldmap)
library(rworldxtra)

cluster = as.numeric(km.res$cluster)

#we plot to map
par(mfrow=c(1,1))
spdf = joinCountryData2Map(data.frame(cluster,df$CountryName), joinCode="NAME", nameJoinColumn="df.CountryName",verbose = TRUE,mapResolution = "low")
mapCountryData(spdf, nameColumnToPlot="cluster", catMethod="fixedWidth",colourPalette=c("#2E9FDF","#00AFBB","#E7B800"), addLegend = FALSE, lwd = 0.5)

##################################SHINY#################################

library(shiny)

# UI
ui <- fluidPage(
  
  titlePanel("WQU Collaborative Review Task 1"),
  
  sidebarLayout(
    
    #Inputs
    sidebarPanel(
      numericInput(
        inputId = 'clusters', 
        label = 'Cluster count', 
        value = 5, 
        min = 2, max = 5),
      width = 2
    ),
    mainPanel(
      tabsetPanel(
        type = "tabs",
        # Tab 1: Plot
        tabPanel(
          title = "Visualization",
          tags$h3("Cluster Plot"),
          plotOutput(outputId = 'clusterplot'), # clusterplot
          br(),
          htmlOutput(outputId = "cluster") # cluster centers
        ),
        
        tags$br(),
        tags$h4("Countries Heatmap"),
        plotOutput(outputId = "heatmap"), # heatmap
        width = 9
      )
    ),
    selectInput(inputId = "scaled_data",
                label = "Choose your Data:",
                choices = c("Aruba","Angola","Albania")),
    
    numericInput(inputId = "obs",
                 label = "Number of observations to view:",
                 value = 10)
  ),
  
)

# Server
server <- function(input, output){
  
  # reactive kmeans clusters
  clusters <- reactive({
    model <- kmeans(scaled_data, input$clusters)
  })
  
  # Create cluster plots
  output$clusterplot <- renderPlot({
    autoplot(clusters(), data = scaled_data, frame = TRUE, label = TRUE)
  })
  
  # display cluster size
  output$cluster <- renderUI({
    model_size <- clusters()$size
    HTML("cluster sizes: ", 
         paste(model_size),
         "<br/>"
    )
  })
  
  # display cluster summary
  output$kmeanssummary <- renderPrint({
    model <- clusters()
    print(summary(model), digits = 3)
  })
  
  # display heatmap
  output$heatmap <- renderPlot({
    autoplot(mydata.sample)
  })
  
  # Generate a summary of the dataset ----
  output$summary <- renderPrint({
    countries <- datasetInput()
    summary(countries)
  })
  
  # Show the first "n" observations ----
  output$view <- renderTable({
    head(datasetInput(), n = input$obs)
  })
}

# Create a shiny app
shinyApp(ui = ui, server = server)
