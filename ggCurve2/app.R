library(shiny)
library(ggplot2)
library(ggvegan)
library(svglite)
library(grDevices)
library(dplyr)

ui <- shinyUI(fluidPage(
    titlePanel("Curvas de Acumulación"),
    tabsetPanel(
        tabPanel("Tabla de Abundancia",
                 titlePanel("Cargando Archivos"),
                 sidebarLayout(
                     sidebarPanel(
                         fileInput("archivo", "Escoge la Matriz de Abundancia",
                                   accept = c(
                                       "text/csv",
                                       "text/comma-separated-values,text/plain",
                                       ".csv"), buttonLabel = "Matriz CSV", placeholder = "No se ha seleccionado la Matriz"),
                         
                         # added interface for uploading data from
                         # http://shiny.rstudio.com/gallery/file-upload.html
                         tags$br(),
                         checkboxInput('header', 'Header', TRUE),
                         radioButtons('sep', 'Separador',
                                      c(Coma=',',
                                        Semicolon=';',
                                        Tab='\t'),
                                      ',')
                         
                     ),
                     mainPanel(
                         tableOutput('contents')
                     )
                 )
        ),
        tabPanel("Gráfico de las Curvas",
                 pageWithSidebar(
                     headerPanel('Especificaciones'),
                     sidebarPanel( numericInput("a", "Ancho(cm):", 16, min = 2, max = 50),
                                   numericInput("l", "Altura(cm):", 8, min = 2, max = 50),
                                   numericInput("p", "Permutaciones", 100, min = 1, max = 20000),
                                   radioButtons("device", "Formato", choices = c("png", "svg"), selected = "png"),
                                   textInput(inputId = "x", label = "Unidad de muestreo", value = "", placeholder = "Titulo del eje X"),
                                   downloadButton('Plot')
                                   
                                   
                     ),
                     mainPanel(
                         plotOutput('curva')
                     )
                 )
        ), 
        tabPanel("Porcentaje de Eficiencia",
                 pageWithSidebar(
                     headerPanel('Tabla de Rendimiento'),
                     sidebarPanel( downloadButton('Porcentaje1')
                                   
                                   
                     ),
                     mainPanel(
                         tableOutput('Porcentaje')
                     )
                 )
        )
        
    )
)
)

# Define server logic required to draw a histogram
server <- shinyServer(function(input, output, session) {
    
    
    
    
    dat <- reactive({ req(input$archivo)
        inFile <- input$archivo
        
        if (is.null(inFile)){
            return(NULL)} 
        
        df<- read.csv(inFile$datapath, header = input$header, sep = input$sep,
                      quote = input$quote)
        
        
    })
    
    output$contents <- renderTable({
        dat()
        
        
    })
    
    grafico <- reactive({
        cum <- dat()
        cum[is.na(cum)] <- 0
        pool1 <- poolaccum(cum[,-1], permutations = input$p)
        print(pool1)
        pool <- fortify(pool1)
        pool <- pool %>% mutate(Metodo = ifelse(Richness < pool$Richness[length(pool$Index == "S")/5], "Interpolated", ifelse(Richness > pool$Richness[length(pool$Index == "S")/5],"Extrapolated", "Observed")))
        pool$Metodo <- factor(pool$Metodo, levels = c("Interpolated", "Extrapolated", "Observed"))
        p <- ggplot(pool, aes(x = Size, y = Richness, colour = Index, linetype = Metodo)) + geom_line(lwd = 1.3) + theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank(),panel.background = element_blank(), axis.line = element_line(colour = "black"), legend.key = element_rect(fill = "white", colour = "white"))   
        p1 <- p + geom_ribbon(aes(ymin = Lower, ymax = Upper, fill = Index), linetype = 0, alpha = 0.1) + guides(linetype = F) + labs(x = input$x, y = "Riqueza", colour = "Índices", fill = "Índices")
        print(p1) })
    
    
    output$curva <- renderPlot({
        print(grafico())
    })
    
    
    output$Plot = downloadHandler(
        filename = function() { paste("Curva", Sys.Date(), paste0(".", input$device)) },
        
        content = function(file) {
            ggsave(file, plot = grafico(), device =  input$device, units = "cm", width = input$a, height = input$l, dpi = 600)
        })
    
    Eficiencia <- reactive({
        cum <- dat()
        cum[is.na(cum)] <- 0
        pool1 <- poolaccum(cum[,-1], permutations = 1000)
        print(pool1)
        pool <- fortify(pool1)
        Indice <- c("Chao", "Jack1", "Jack2", "Boot")
        Eficiencia1 <- pool$Richness[length(pool$Index=="S")/5] / pool$Richness[c(length(pool$Index=="S")*2/5, length(pool$Index=="S")*3/5, length(pool$Index=="S")*4/5, length(pool$Index=="S")*5/5)] 
        Eficiencia <- round(x = Eficiencia1 * 100, digits = 3)
        td <- rbind("",  paste(Eficiencia, "%"))
        colnames(td) <- Indice
        print(td)
    })
    output$Porcentaje <- renderTable({
        Eficiencia()
        
        
    })
    
    output$Porcentaje1 <- downloadHandler(
        filename = function() {
            paste(input$dataset, ".csv", sep = "")
        },
        content = function(file) {
            write.csv(datasetInput(), file, row.names = FALSE)
        }
    )
    
    
})

# Run the application 
shinyApp(ui = ui, server = server)
