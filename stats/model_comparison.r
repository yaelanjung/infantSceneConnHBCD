# this particular script is set up to create Figure 3
# and conduct relevant statistical analysis
# but the similar analyses were conducted for Figure 2 & 4
# Yaelan J. (Oct 22, 2026)

## setup wd
#setwd('YOUR_PATH_TO_WD')

## load libraries
library(ppcor)
library(dplyr)
library(ggplot2)
library(DescTools)
library(tidyverse)
library(ggrepel)

# load the data
#res.df <- read.csv(#YOUR_PATH_TO_SOURCE_DATA")
head(res.df)
res.df <- res.df %>% dplyr::select(-X)
res.df <- res.df %>% filter(model == 'Three-System')
res.df$model <- ordered(res.df$model, levels = c('Three-System', 'model_2A', 'model_2B', 'model_2C'))

levels(res.df$model) <- c("Three-System", "Two-System:A", 
                          "Two-System:B", "Two-System:C")

# plot it
ggplot(res.df, aes(x = model, y = rsa, fill = model)) +
  geom_bar(width = 0.5, stat = 'summary') +
  stat_summary(fun.data = mean_se, geom = "errorbar", width = 0.1) +
  geom_point(stat = "identity", alpha = 0.03, size = 0.25,
             position = position_jitter(width = 0.05, height = 0)) +
  scale_fill_manual(values = c("#78a9d6", "#828282", "#b5b3b4", "#e0e0e0")) +
  xlab('') +
    ylim(-.6,0.8)  +
  ylab('Pattern Similarity') +
  theme_classic() + 
  theme(legend.position = 'none', 
        axis.text = element_text(size = 18),
        axis.title = element_text(size =20))


levels(res.df$model)
res.df$z_val <- atanh(res.df$rsa)

# anova
res.df$z_val <- atanh(res.df$rsa)
mdl <- anova_test(data = res.df,
                  dv = z_val,
                  within = model,
                  wid = subject, 
                  effect.size = 'pes', type = 1)

get_anova_table(mdl)

# contrast analysis
mdl <- lm(
  z_val ~ model + subject,
  data = res.df
)

anova(mdl)  # omnibus effect of model
emm <- emmeans(mdl, ~ model)
contrast(
  emm,
  method = list(
    "Three-system vs Alt 1" = c(1, -1, 0, 0),
    "Three-system vs Alt 2" = c(1, 0, -1, 0),
    "Three-system vs Alt 3" = c(1, 0, 0, -1)
  ),
  adjust = "none"
)