
generate_state_plot_layer <- function(data_to_plot) {
  
  names(data_to_plot)[2] = "value"
  data_to_plot_reduced = mtconnectR::clean_reduntant_rows(data_to_plot)
  data_to_plot_reduced = data_to_plot_reduced %>% rbind(data_to_plot[nrow(data_to_plot),]) %>% unique()
  start_values = data_to_plot_reduced[1:(nrow(data_to_plot_reduced) - 1), 1]
  end_values = data_to_plot_reduced[2:nrow(data_to_plot_reduced), 1]
  value = NULL # cran check 
  
  ggplot() + geom_rect(data = data_to_plot_reduced[-nrow(data_to_plot_reduced),],
                       aes(xmin = start_values, xmax = end_values,
                       ymin = 0L, ymax = 1L, fill = value)) 
}

generate_numeric_plot_layer <- function(data_to_plot, current_ylimit, plot_fun, line_width=0.3) {
  names(data_to_plot)[2] = "value"
  ggplot() + 
    plot_fun(data=data_to_plot, aes_string(x = names(data_to_plot)[1], y = "value", group = 1), size = line_width) +
    coord_cartesian(ylim = current_ylimit)
    
}


create_state_plots <- function(timeline_cleaned, ts_col, state_cols){
  flog.info("creating state plot layers")
  
  state_plots <- sapply(state_cols, function(x) generate_state_plot_layer(timeline_cleaned[, c(ts_col, x)]),
                        simplify = F, USE.NAMES = T)
  
  #state_plots <- state_plots[!vapply(X = event_plots, FUN = is.null, FUN.VALUE = FALSE,USE.NAMES = FALSE)]
  return(state_plots)
}


get_numeric_plot_function <- function(numeric_plot_type){
  if(numeric_plot_type == "line" ) return(geom_line)
  if(numeric_plot_type == "step" ) return(geom_step)
  if(numeric_plot_type == "point" ) return(geom_point)
  stop("Unsupported plot type for numeric data type")
}


create_numeric_plots <- function(timeline_cleaned, ts_col, numeric_cols, actual_ylimits, numeric_plot_type){
  flog.info("creating sample plot layers")
  plot_fun = get_numeric_plot_function(numeric_plot_type)
  numeric_plots <- mapply(current_plot = numeric_cols, current_ylimit = actual_ylimits,
                          FUN = function(current_plot, current_ylimit)
                            generate_numeric_plot_layer(timeline_cleaned[, c(ts_col, current_plot)], current_ylimit, plot_fun),
                          SIMPLIFY = F, USE.NAMES = T)
  
  return(numeric_plots)
}

#  We now have all_plots which is a list of ggplots with automatic legend scales
#  Options for adding legend location details and specifying the colors in case of event plots
#  plot_type is used here which is just the titles as a named list
# Check what color is given to those variables which does not exist in the scales
# Use scale_manual as a layer for ggplot
add_legend_to_plots <- function(all_plots, add_legend){
  
  all_plots <- lapply(all_plots, function(basic_plot) {
    basic_plot <- basic_plot + theme(panel.background = element_rect(fill="#EEEEEE", colour="black"),
                                     legend.justification=c(1,1),legend.direction = "horizontal",
                                     legend.title=element_blank())
    if(add_legend) {
      basic_plot <- basic_plot + theme(legend.position=c(1,1))
    } else {
      basic_plot <- basic_plot + theme(legend.position="none")
    }
    
    basic_plot
  })
  return(all_plots)
}

check_colors_mapping <- function(state_factors, user_defined_mapping){
  if(length(names(user_defined_mapping)) == length(state_factors)){
    if(length(setdiff(names(user_defined_mapping), state_factors)) == 0){
      return(T)
    }
  }
  return(F)
}

add_colors_to_state_plots <- function(all_plots, color_mapping, unique_state_factors){
  
  names_all_plots <- names(all_plots)
  all_plots <- lapply(1:length(all_plots), function(i) {
    basic_plot <- all_plots[[i]]
    basic_plot <- basic_plot + scale_y_continuous(breaks = NULL)
    name_plot <- names_all_plots[[i]]
    user_defined_mapping <- color_mapping[[name_plot]]
    state_factors <- unique_state_factors[[name_plot]]
    
    if(!is.null(user_defined_mapping)){
      if(check_colors_mapping(state_factors, user_defined_mapping)){
        basic_plot <- basic_plot + scale_fill_manual(values = user_defined_mapping)
      }else{
        stop("Expected same number of colors as the number of factors")
      }
    }
    basic_plot  
  })
  names(all_plots) <- names_all_plots
  return(all_plots)
}

get_plot_limits <- function(timeline_cleaned, numeric_plots, ylimits){
  numeric_cols = names(timeline_cleaned)[timeline_cleaned %>% sapply(is.numeric)]
  
  default_ylimits <- rep(list(NULL), length(numeric_plots))
  names(default_ylimits) <- numeric_cols
  
  default_ylimits[names(ylimits)] = ylimits
  default_ylimits[numeric_cols]
}

# The titles list has all the info including the ones for overlapping plots
# so we add a filter to keep only the names in the plots
add_titles_to_the_plot <- function(all_plots, titles){
  default_titles <- names(all_plots)
  names(default_titles) <- names(all_plots)
  
  if(!is.null(titles)) {
    flog.info("Adding new plot titles")
    default_titles[names(titles)] <- titles
  }
  default_titles = default_titles[names(default_titles) %in% names(all_plots)]
  all_plots <- mapply(FUN = function(x,y) x + ggtitle(y), x=all_plots, y=default_titles, SIMPLIFY = FALSE,USE.NAMES = TRUE)
  return(all_plots)
}


add_ylabels_to_the_plot <- function(all_plots, ylabels, state_cols){
  default_ylabs <- sapply(names(all_plots), function(x){
    if(x %in% state_cols) return("State") else return("Numeric")
  })
  names(default_ylabs) <- names(all_plots)
  if(!is.null(ylabels)) {
    flog.info("Adding new y-labels")
    default_ylabs[names(ylabels)] <- ylabels
  }
  default_ylabs <- default_ylabs[names(all_plots)]
  all_plots <- mapply(FUN = function(x,y) x + ylab(y), x = all_plots, y = default_ylabs, SIMPLIFY = FALSE, USE.NAMES = TRUE)
  return(all_plots)
}

scale_grob_plots <- function(all_plots_grob, plot_size_ratios){
  # browser()
  names(all_plots_grob)
  
  plot_size_ratios_all = structure(rep(1, length(all_plots_grob)), names=names(all_plots_grob))
  if(!is.null(plot_size_ratios)) plot_size_ratios_all[names(plot_size_ratios)] = plot_size_ratios
  
  mapply(x = all_plots_grob, y = plot_size_ratios_all, FUN = function(x,y) {
    which_panel <- which(x$layout$name == "panel")
    x$heights[which_panel] =  x$heights[which_panel] * y
    x
  })
}


combine_the_grobs <- function(all_plots_grob_scaled){
  num_rows <- unname(vapply(all_plots_grob_scaled, FUN = nrow, FUN.VALUE = 0L))
  num_rows <- c(0,num_rows[-length(num_rows)]) %>% cumsum
  
  mapply(x = all_plots_grob_scaled, y = num_rows, function(x,y) {
    x$layout$t <- x$layout$t + y
    x$layout$b <- x$layout$b + y
    x
  })
}

rbind_grob_plots <- function(all_plots_grob_scaled){

  num_cols <- vapply(all_plots_grob_scaled, FUN = ncol, FUN.VALUE = 0L)
  if(length(unique(num_cols))!=1) stop("number of cols are not the same for all the ggplots!")
  
  max_widths <- Reduce(f = grid::unit.pmax,x = lapply(all_plots_grob_scaled, function(x) x$widths))
  
  all_grobs <- Reduce(f = append,x = lapply(all_plots_grob_scaled,function(x) x$grobs))
  all_heights <- Reduce(f = grid::unit.c,x = lapply(all_plots_grob_scaled,function(x) x$heights))
  all_rownames <- Reduce(f = c,x = lapply(all_plots_grob_scaled,function(x) x$rownames))

  single_plot_scaled <- combine_the_grobs(all_plots_grob_scaled)

  all_layout <- Reduce(f = rbind, x = lapply(single_plot_scaled,function(x) x$layout))

  final_plot <- single_plot_scaled[[1]]
  final_plot$layout <- all_layout
  final_plot$heights <- all_heights
  final_plot$rownames <- all_rownames
  final_plot$widths <- max_widths
  final_plot$grobs <- all_grobs

  final_plot
}

adjust_legend_position <- function(all_plots_grob){
  
  # This function relocated the legend and adjusts the size for a state plot
  # We first find the location of the legend - 'guide-box' and then if it exists (state plot)
  # We move the legend to the x-lab row and then adjust the height of the row to the height
  # that we are getting from the height of the entire guide box(which is a grob in itself)
  
  mapply(x = all_plots_grob, FUN = function(x) {
    # browser()
    which_guide <- which(x$layout$name == "guide-box")
    if(length(which_guide) == 0) return(x)
    which_caption <- which(x$layout$name == "xlab-b")
    x$layout[which_guide, c('t', 'b')] =  x$layout[which_caption, c('t', 'b')] 
    x$heights[x$layout[which_guide, c('t')]] = x$grobs[[which_guide]]$heights %>% max()
    x
  })
}

align_the_plots <- function(all_plots, overlap_plots_grob, plot_size_ratios, order_plots){
  message("Aligning plots")
  all_plots_grob <- lapply(all_plots, ggplotGrob)
  all_plots_grob = c(all_plots_grob, overlap_plots_grob)
    
  all_plots_grob = adjust_legend_position(all_plots_grob)
  all_plots_grob_scaled <- scale_grob_plots(all_plots_grob, plot_size_ratios)
  if(!is.null(order_plots)) all_plots_grob_scaled <- all_plots_grob_scaled[order_plots]
  all_plots_rbind <- rbind_grob_plots(all_plots_grob_scaled)
  
  all_plots_rbind
}


draw_the_plots <- function(grob_output, save_path, plot_output = T, output_width, output_height){
  if(!is.null(save_path)) {
    flog.info("Writing image to file as PNG in: ",  save_path)
    png(save_path, width = output_width, height = output_height)
    grid::grid.draw(grob_output)
    dev.off() 
  }
  
  if(plot_output) {
    message("Plotting")
    grid::grid.draw(grob_output)
  }
}

# If need arises to add xlabel, they can be added as prefix by passing to this function
add_pretty_breaks_and_labels_to_one_oplot <- function(ggobject, labels_list){
  ggobject + xlab(labels_list$xlabel) + 
    scale_x_datetime(breaks = labels_list$prt_brks, labels = labels_list$brk_labels)
}


get_pretty_breaks_labels <- function(time_limits){
  prt_brks <- base::pretty(n = 10, x = time_limits)
  xlabels <- attr(prt_brks, "labels")
  
  break_patterns = list(
    "Time (HH:MM:SS)"   = "^[[:digit:]]+:[[:digit:]]+:[[:digit:]]+$",
    "Time (HH:MM)"      = "^[[:digit:]]+:[[:digit:]]+$",
    "Time (s)"          = "^[[:digit:]]+$",
    "Time (Date HH:MM)" = "^[[:alpha:]]+ [[:digit:]]+ [[:digit:]]+:[[:digit:]]+$",
    "Time (Date)"       = "^[[:alpha:]]+ [[:digit:]]+$",
    "Time (Date-Month)" = "^[[:alpha:]]+"
  )
  which_pattern = which(sapply(break_patterns, function(x) str_detect(xlabels[2], x)))
  if(length(which_pattern) == 0)  stop("Coudn't find break pattern!")
  
  xlabels[1] <- as.character(prt_brks[1])
  list(prt_brks = prt_brks, brk_labels = xlabels, xlabel = names(which_pattern)[1])
}


add_pretty_breaks_and_xlabel <- function(all_plots, time_limits) {
  labels_list <- get_pretty_breaks_labels(time_limits)

  sapply(X = all_plots, FUN = add_pretty_breaks_and_labels_to_one_oplot,
         labels_list, USE.NAMES = TRUE, simplify = F)
  
}


add_grob_to_pos <- function(input_grob, add_grob_table, layout_name){
  add_pos <- subset(add_grob_table$layout, add_grob_table$layout$name == layout_name)[, c("t", "l", "b", "r")]
  add_grob <- add_grob_table$grobs[[which(add_grob_table$layout$name == layout_name)]]
  combined_grob <- gtable_add_grob(input_grob, add_grob, 
                                   add_pos$t, add_pos$l, add_pos$b, add_pos$r)
  return(combined_grob)
}

check_overlap_plottability <- function(overlap_plots, state_cols, numeric_cols){
  all(sapply(overlap_plots, function(x) x[1] %in% state_cols &
           x[2] %in% numeric_cols))
}

create_all_overlapping_plots <- function(all_plots, state_cols, numeric_cols, overlap_plots, titles){
  if(!check_overlap_plottability(overlap_plots, state_cols, numeric_cols)) 
    stop("Incorrect combination of state and numeric plots")
  
  sapply(names(overlap_plots), function(name_plot) {
      x = overlap_plots[[name_plot]]
      if(name_plot %in% names(titles)){
        create_overlapping_plot(all_plots[[x[1]]], all_plots[[x[2]]], titles[[name_plot]])
      }else{
        create_overlapping_plot(all_plots[[x[1]]], all_plots[[x[2]]], name_plot)
      }
    },
    USE.NAMES = T, simplify = F)
}

create_overlapping_plot <- function(state_plot, numeric_plot, title_name){
  state_plot <- state_plot + theme(panel.grid.minor = element_blank(),
                                   panel.grid.major = element_blank()) + ylab("") + ggtitle(title_name)
  
  numeric_plot <- numeric_plot + theme(panel.grid.minor = element_blank(),
                                       panel.grid.major = element_blank(),
                                       panel.background = element_rect(fill = "transparent", colour = NA), 
                                       plot.background = element_rect(fill = "transparent", colour = NA))
  
  state_grob_table <- ggplot_build(state_plot) %>% ggplot_gtable()
  numeric_grob_table <- ggplot_build(numeric_plot) %>% ggplot_gtable()
  
  combined_grob <- add_grob_to_pos(state_grob_table, numeric_grob_table, "panel")
  combined_grob <- add_grob_to_pos(combined_grob, numeric_grob_table, "ylab-l")
  combined_grob <- add_grob_to_pos(combined_grob, numeric_grob_table, "axis-l")
  
  combined_grob$widths[3] = numeric_grob_table$widths[3]
  return(combined_grob)
}

#' @title Generate color mapping for all plots
#' @description When all the plots have the same set of values, instead of typing the color mapping for all plots, default color to value mapping can be given which will generate the color mapping for all the plots based on the unique values present in each column
#' @param df Data frame to be plotted using plot_timeline
#' @param default_color_mapping Value to color mapping for all the plots in the data frame. ex: default_color_mapping <- c("0" = "#BCBEC0", "1" = "#1279C6")
#' @usage 
#' generate_color_mapping(df, default_color_mapping)
#' @export

generate_color_mapping <- function(df, default_color_mapping) {
  timestamp = NULL
  df <- df %>% dplyr::select(-timestamp)
  cols_name <- colnames(df)
  
  color_mapping <- lapply(cols_name, function(l) {
    unique_values_cols <- unique(df[[l]])
    req_mapping <- default_color_mapping[names(default_color_mapping) %in% unique_values_cols]
    req_mapping
  })
  names(color_mapping) <- cols_name
  color_mapping
}
