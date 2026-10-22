# this particular script is set up to create Figure 7
# and conduct relevant statistical analysis
# but the similar analyses were conducted for Figure 6
# Yaelan J. (Oct 22, 2026)

## setup wd + load the data ##
#setwd('YOUR_PATH_TO_WD')

## load libraries
library(ppcor)
library(dplyr)
library(ggplot2)
library(DescTools)
library(tidyverse)
library(ggrepel)


#### load the data ####
#df.res <- read.csv("YOUR_PATH_TO_SOURCE_DATA")

df.res$edge_type <- as.factor(df.res$edge_type)
levels(df.res$edge_type) <- c("OPA-Hippo", "PPA-Hippo",
                              "RSC-Hippo", "SPA-Hippo")
df.res$edge_type <- ordered(df.res$edge_type, levels = c("PPA-Hippo", "RSC-Hippo",
                                                         "OPA-Hippo", "SPA-Hippo"))
head(df.res)
levels(df.res$edge_type) <- c("PPA", "RSC",
                              "OPA", "SPA")

# plot it 
ggplot(df.res, aes(x = age_month, y = r_vals, color = edge_type)) +
  geom_point(size = 1, alpha = 0.1) +
  scale_color_manual(values = c("#B02418", "#239C5A", "#3C66D4", "#274697")) +
  # Linear regression line with confidence interval
  geom_smooth(method = "lm", formula = y ~ x, se = TRUE, aes(group = edge_type),
                                                             linewidth = 1.5) +
  labs(
    x = "Age (month)",
    y = "Hippocampal Connection (r)"
  ) +
  ylim(-0.6, 0.8) +
  theme_classic() +
  theme(legend.position = 'top', 
        legend.title = element_blank(),
        legend.text = element_text(size = 18),
        legend.key.size = unit(0.4, "cm"),
        axis.text = element_text(size = 18),
        axis.title = element_text(size = 22)) +
  guides(color = guide_legend(nrow = 2))


##### : stats : #####
library(lme4)
library(lmerTest)

df.res$edge_type <- factor(df.res$edge_type)
df.res$z_val <- atanh(df.res$r_vals)

df.res <- df.res %>%
  mutate(age_c = age_month - mean(age_month, na.rm = TRUE))

model_linear <- lmer(
  z_val ~ age_c * edge_type + (age_c | subject),
  data = df.res
)

summary(model_linear)
anova(model_linear, type = 3)
confint(
  model_linear,
  parm = "beta_",
  method = "Wald",
  level = 0.95
)

# check the slope
model_linear <- lmer(
  z_val ~ age_c * edge_type + (age_c | subject),
  data = df.res
)

levels(df.res$edge_type)

# check trends
library(emmeans)
hipp_slopes <- emtrends(model_linear, ~ edge_type, var = "age_c")
summary(hipp_slopes, infer = TRUE)

# contrast analysis: RSC vs. Others
rsc_vs_others <- contrast(
  hipp_slopes,
  method = list(
    "RSC-Hipp vs other scene regions" =
      c(-1/3, 1, -1/3, -1/3)
  )
)

summary(rsc_vs_others, infer = TRUE)


# linear vs polynomial
model_quad <- lmer(
  z_val ~ poly(age_month, 2) * edge_type + (age_month | subject),
  data = df.res
)

anova(model_linear, model_quad)
summary(model_quad)