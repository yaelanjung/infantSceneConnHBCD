## setup wd + load the data ##
#setwd(#YOUR_PATH_TO_WORKING_DIRECTORY#)

## load libraries
library(dplyr)
library(tidyverse)
library(ggrepel)

#dt_master <- read.csv("YOUR_PATH_TO_CSV_FILE")

######## : variables : ########
subjects <- unique(dt_master$sub_id)
all_subj_matrices <- list()

# Define the full set of ROIs 
target_rois <- c(
  "lPPA", "lOPA", "lRSC", "lSPL",
  "rPPA", "rOPA", "rRSC", "rSPL" 
)
scene_rois <- target_rois

######## : Loop over subjects : ########
df.res <- data.frame()
subj.list = list()

for (subj in subjects) {
  
  subj_data <- dt_master %>% filter(sub_id == subj)
  
  # quick clean up
  node_data <- subj_data %>% 
    select(all_of(intersect(target_rois, colnames(subj_data)))) %>% 
    drop_na()
  
  # Calculate Full Pearson Correlation Matrix
  cor_matrix <- cor(node_data, method = "pearson")
  
  # Store in our list
  all_subj_matrices[[as.character(subj)]] <-  cor_matrix 
}

######## : RSA analysis : ########
# model RDMs
model_3systems <- matrix(c(
  0,1,1,1,  # PPA
  1,0,1,0,  # OPA
  1,1,0,1,  # RSC
  1,0,1,0   # SPL — OPA & SPA are similar (value = 0)
), nrow=4, byrow=TRUE)


# permutation Loop
subject_results <- data.frame()
model_4x4 <- model_3systems
all_null_rs <- c()

for (subj in subjects) {
  subj_data <- dt_master %>% filter(sub_id == subj)
  
  # quick clean up
  node_data <- subj_data %>% 
    select(all_of(intersect(target_rois, colnames(subj_data)))) %>% 
    drop_na()

  r_mat <- cor(node_data, method = "pearson")
  
  roi_names <- c('lPPA', 'lOPA','lRSC', 'lSPL',
                 'rPPA', 'rOPA', 'rRSC', 'rSPL')
  
  r_mat <- r_mat[roi_names, roi_names]
  
  n_roi <- length(roi_names) / 2  
  generic_names <- c("PPA", "OPA", "RSC", "SPL")
  
  # 1. Extract the Quadrants
  LH_LH <- r_mat[1:n_roi, 1:n_roi]
  RH_RH <- r_mat[(n_roi + 1):(2 * n_roi), (n_roi + 1):(2 * n_roi)]
  
  LH_RH <- r_mat[1:n_roi, (n_roi + 1):(2 * n_roi)]
  RH_LH <- r_mat[(n_roi + 1):(2 * n_roi), 1:n_roi]
  
  # Average them to collapse hemispheres
  r_within_collapsed <- (LH_LH + RH_RH) / 2
  r_between_collapsed <- (LH_RH + t(RH_LH)) / 2
  
  off_diag_mask <- matrix(TRUE, nrow = nrow(r_between_collapsed), ncol = ncol(r_between_collapsed))
  diag(off_diag_mask) <- FALSE
  
  neural_dist_mat <- 1 - r_between_collapsed
  
  neural_vec <- neural_dist_mat[off_diag_mask]
  model_vec <- model_3systems[off_diag_mask]

  obs_r <- cor(neural_vec, model_vec, method = "pearson")
  
  # perm value
  perm_idx <- sample(original_idx)
    
  # shuffle rows and columns of the model
  shuffled_model <- model_4x4[perm_idx, perm_idx]
  shuffled_vector <- shuffled_model[off_diag_mask]
    
  null_r = cor(neural_vec, shuffled_vector, method = "pearson")
  
  subject_results <- bind_rows(subject_results, data.frame(
    sub_id = subj,
    Observed_R = obs_r,
    Null_R = null_r)
  )

}


subject_results$obs_z <- atanh(subject_results$Observed_R)
subject_results$null_z <- atanh(subject_results$Null_R)


######## : plot it : ########
# Reshape for plotting
plot_df <- subject_results %>%
  pivot_longer(cols = c(Observed_R, Null_R_Mean), 
               names_to = "Condition", 
               values_to = "Pearson_R")

plot_df$Condition <- as.factor(plot_df$Condition)
levels(plot_df$Condition)
plot_df$Condition <- ordered(plot_df$Condition, levels = c('Observed_R', 'Null_R_Mean'))

levels(plot_df$Condition) <- c("Three-system", "Null")
plot_df <- plot_df %>% dplyr::select(-X)


ggplot(plot_df, aes(x = Condition, y = Pearson_R, fill = Condition)) +
  geom_line(aes(group = sub_id), alpha = 0.1, color = "gray") + # The 'Fair' contrast
  geom_point(aes(color = Condition), alpha = 0.6, size = .8,
             position = position_jitter(width = 0.05)) +
  geom_pointrange(stat = "summary", fun.data = "mean_cl_normal", size = 0.5) +
  scale_x_discrete(labels = c("No Functional Specificity (H0)", 
                              "Three-system Model (H1)")) +
  theme_classic() +
  scale_color_manual(values = c( "#4a7ab5", "#c17a74")) +
  ylim(-1, 1) +
  labs(y = "Pattern Similarity", x = '') +
  theme(legend.position = 'none', 
        axis.text = element_text(size = 17),
        axis.title = element_text(size = 24))

