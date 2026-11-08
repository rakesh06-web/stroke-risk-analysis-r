# ============================================================
# STROKE RISK ANALYSIS USING R
# ============================================================

# Load libraries
library(dplyr)
library(ggplot2)

# Set working directory
# Run this script from the repository folder.
# In RStudio, open the repository as a project or set the working directory to this folder.
dir.create("visualizations", showWarnings = FALSE)
dir.create("results", showWarnings = FALSE)

# Load dataset
stroke_data <- read.csv("data/healthcare-dataset-stroke-data.csv")

# ============================================================
# 1. DATA CLEANING
# ============================================================

# Check dataset
dim(stroke_data)
names(stroke_data)
str(stroke_data)
summary(stroke_data)

# Check missing values
colSums(is.na(stroke_data))

# Check duplicate records
sum(duplicated(stroke_data$id))

# Check stroke values
table(stroke_data$stroke)

# Create cleaned dataset
stroke_clean <- stroke_data %>%
  distinct(id, .keep_all = TRUE) %>%
  mutate(
    gender = factor(gender),
    smoking_status = na_if(smoking_status, "Unknown"),
    smoking_status = factor(smoking_status),
    
    age_group = cut(
      age,
      breaks = c(-Inf, 18, 30, 45, 60, 75, Inf),
      labels = c(
        "0-18",
        ">18-30",
        ">30-45",
        ">45-60",
        ">60-75",
        "75+"
      )
    )
  )

# Check cleaned dataset
dim(stroke_clean)
colSums(is.na(stroke_clean))
table(stroke_clean$age_group)

# ============================================================
# 2. STROKE OCCURRENCE BY AGE GROUP
# ============================================================

# Calculate stroke occurrence rate by age group
age_summary <- stroke_clean %>%
  group_by(age_group) %>%
  summarise(
    total_people = n(),
    stroke_cases = sum(stroke),
    stroke_rate = mean(stroke) * 100,
    .groups = "drop"
  )

print(age_summary)

# Create age group visualization
age_plot <- ggplot(
  age_summary,
  aes(x = age_group, y = stroke_rate)
) +
  geom_col(
    fill = "#3973AC",
    width = 0.65
  ) +
  geom_text(
    aes(
      label = paste0(
        round(stroke_rate, 1),
        "%\n(n=",
        total_people,
        ")"
      )
    ),
    vjust = -0.4,
    size = 3.8
  ) +
  scale_y_continuous(
    expand = expansion(mult = c(0, 0.2))
  ) +
  labs(
    title = "Stroke Occurrence Rate by Age Group",
    subtitle = "Percentage of individuals with stroke in each age group",
    x = "Age Group",
    y = "Stroke Occurrence Rate (%)",
    caption = "Source: Stroke Prediction Dataset"
  ) +
  theme_minimal(base_size = 13)

print(age_plot)

# Save age group visualization
ggsave(
  "visualizations/stroke_rate_by_age.png",
  plot = age_plot,
  width = 10,
  height = 6,
  dpi = 300
)

# ============================================================
# 3. GENDER AND STROKE OCCURRENCE
# ============================================================

# Calculate stroke occurrence rate by gender
gender_summary <- stroke_clean %>%
  filter(gender %in% c("Male", "Female")) %>%
  group_by(gender) %>%
  summarise(
    total_people = n(),
    stroke_cases = sum(stroke),
    stroke_rate = mean(stroke) * 100,
    .groups = "drop"
  )

print(gender_summary)

# Create gender visualization
gender_plot <- ggplot(
  gender_summary,
  aes(x = gender, y = stroke_rate)
) +
  geom_col(
    fill = "#3973AC",
    width = 0.55
  ) +
  geom_text(
    aes(
      label = paste0(
        round(stroke_rate, 2),
        "%\n(n=",
        total_people,
        ")"
      )
    ),
    vjust = -0.5,
    size = 4
  ) +
  scale_y_continuous(
    expand = expansion(mult = c(0, 0.2))
  ) +
  labs(
    title = "Stroke Occurrence Rate by Gender",
    subtitle = "Percentage of individuals with stroke within each gender group",
    x = "Gender",
    y = "Stroke Occurrence Rate (%)",
    caption = "Source: Stroke Prediction Dataset"
  ) +
  theme_minimal(base_size = 13)

print(gender_plot)

# Save gender visualization
ggsave(
  "visualizations/stroke_rate_by_gender.png",
  plot = gender_plot,
  width = 9,
  height = 6,
  dpi = 300
)

# ============================================================
# 4. GENDER AND STROKE LOGISTIC REGRESSION
# ============================================================

# Prepare data for gender analysis
gender_data <- stroke_clean %>%
  filter(gender %in% c("Male", "Female")) %>%
  droplevels()

# Set reference category
gender_data$gender <- relevel(
  gender_data$gender,
  ref = "Female"
)

# Logistic regression adjusting for age
gender_model <- glm(
  stroke ~ age + gender,
  data = gender_data,
  family = binomial
)

# View results
print(summary(gender_model))

# Calculate odds ratios
print(exp(coef(gender_model)))

# Calculate 95% confidence intervals
print(exp(confint.default(gender_model)))

# ============================================================
# 5. AGE AND STROKE ANALYSIS
# ============================================================

# Compare average ages
age_statistics <- stroke_clean %>%
  group_by(stroke) %>%
  summarise(
    total_people = n(),
    average_age = mean(age),
    median_age = median(age),
    standard_deviation = sd(age),
    .groups = "drop"
  )

print(age_statistics)

# Welch's t-test
age_test <- t.test(
  age ~ stroke,
  data = stroke_clean
)

print(age_test)

# Logistic regression
age_model <- glm(
  stroke ~ age,
  data = stroke_clean,
  family = binomial
)

print(summary(age_model))

# Odds ratio for each additional year of age
print(exp(coef(age_model)["age"]))

# 95% confidence interval
print(exp(confint.default(age_model)["age", ]))

# ============================================================
# 6. AGE LOGISTIC REGRESSION VISUALIZATION
# ============================================================

# Create ages for prediction
age_predictions <- data.frame(
  age = seq(
    min(stroke_clean$age),
    max(stroke_clean$age),
    length.out = 200
  )
)

# Predict on the log-odds scale
pred <- predict(
  age_model,
  newdata = age_predictions,
  type = "link",
  se.fit = TRUE
)

# Convert predictions to probabilities
age_predictions$probability <- plogis(pred$fit)

age_predictions$lower_ci <- plogis(
  pred$fit - 1.96 * pred$se.fit
)

age_predictions$upper_ci <- plogis(
  pred$fit + 1.96 * pred$se.fit
)

# Create visualization
age_regression_plot <- ggplot(
  age_predictions,
  aes(x = age, y = probability)
) +
  geom_ribbon(
    aes(
      ymin = lower_ci,
      ymax = upper_ci
    ),
    fill = "#BFD7EA",
    alpha = 0.5
  ) +
  geom_line(
    color = "#21618C",
    linewidth = 1.2
  ) +
  scale_y_continuous(
    labels = scales::percent_format(accuracy = 1)
  ) +
  labs(
    title = "Predicted Stroke Probability by Age",
    subtitle = "Logistic regression with 95% confidence interval",
    x = "Age (years)",
    y = "Predicted Probability of Stroke",
    caption = "Source: Stroke Prediction Dataset"
  ) +
  theme_minimal(base_size = 13)

print(age_regression_plot)

# Save visualization
ggsave(
  "visualizations/age_logistic_regression.png",
  plot = age_regression_plot,
  width = 10,
  height = 6,
  dpi = 300
)

# ============================================================
# 7. MEDICAL CONDITIONS AND STROKE ANALYSIS
# ============================================================

# Hypertension comparison
hypertension_summary <- stroke_clean %>%
  group_by(hypertension) %>%
  summarise(
    total_people = n(),
    stroke_cases = sum(stroke),
    stroke_rate = mean(stroke) * 100,
    .groups = "drop"
  ) %>%
  mutate(
    condition = "Hypertension",
    status = ifelse(hypertension == 1, "Yes", "No")
  )

# Heart disease comparison
heart_summary <- stroke_clean %>%
  group_by(heart_disease) %>%
  summarise(
    total_people = n(),
    stroke_cases = sum(stroke),
    stroke_rate = mean(stroke) * 100,
    .groups = "drop"
  ) %>%
  mutate(
    condition = "Heart Disease",
    status = ifelse(heart_disease == 1, "Yes", "No")
  )

# Combine results
condition_summary <- bind_rows(
  hypertension_summary %>%
    select(
      condition,
      status,
      total_people,
      stroke_cases,
      stroke_rate
    ),
  
  heart_summary %>%
    select(
      condition,
      status,
      total_people,
      stroke_cases,
      stroke_rate
    )
)

print(condition_summary)

# ============================================================
# 8. MEDICAL CONDITIONS VISUALIZATION
# ============================================================

condition_plot <- ggplot(
  condition_summary,
  aes(x = status, y = stroke_rate, fill = status)
) +
  geom_col(width = 0.6) +
  geom_text(
    aes(
      label = paste0(
        round(stroke_rate, 1),
        "%\n(n=",
        total_people,
        ")"
      )
    ),
    vjust = -0.5,
    size = 4
  ) +
  facet_wrap(~condition) +
  scale_y_continuous(
    expand = expansion(mult = c(0, 0.2))
  ) +
  labs(
    title = "Stroke Occurrence by Medical Condition",
    subtitle = "Observed stroke rates among individuals with and without each condition",
    x = "Has Medical Condition",
    y = "Stroke Occurrence Rate (%)",
    caption = "Source: Stroke Prediction Dataset"
  ) +
  theme_minimal(base_size = 13) +
  theme(legend.position = "none")

print(condition_plot)

# Save visualization
ggsave(
  "visualizations/stroke_by_medical_condition.png",
  plot = condition_plot,
  width = 10,
  height = 6,
  dpi = 300
)

# ============================================================
# 9. SMOKING STATUS AND STROKE OCCURRENCE
# ============================================================

# Calculate stroke occurrence rate by smoking status
smoking_summary <- stroke_clean %>%
  filter(!is.na(smoking_status)) %>%
  group_by(smoking_status) %>%
  summarise(
    total_people = n(),
    stroke_cases = sum(stroke),
    stroke_rate = mean(stroke) * 100,
    .groups = "drop"
  )

print(smoking_summary)

# Create smoking visualization
smoking_plot <- ggplot(
  smoking_summary,
  aes(x = smoking_status, y = stroke_rate)
) +
  geom_col(
    fill = "#3973AC",
    width = 0.6
  ) +
  geom_text(
    aes(
      label = paste0(
        round(stroke_rate, 1),
        "%\n(n=",
        total_people,
        ")"
      )
    ),
    vjust = -0.5,
    size = 4
  ) +
  scale_y_continuous(
    expand = expansion(mult = c(0, 0.2))
  ) +
  labs(
    title = "Stroke Occurrence by Smoking Status",
    subtitle = "Observed stroke rates among participants with known smoking status",
    x = "Smoking Status",
    y = "Stroke Occurrence Rate (%)",
    caption = "Source: Stroke Prediction Dataset"
  ) +
  theme_minimal(base_size = 13)

print(smoking_plot)

# Save visualization
ggsave(
  "visualizations/stroke_by_smoking_status.png",
  plot = smoking_plot,
  width = 10,
  height = 6,
  dpi = 300
)

# ============================================================
# 10. MULTIPLE LOGISTIC REGRESSION
# ============================================================

# Prepare data for medical conditions analysis
medical_data <- stroke_clean %>%
  filter(
    !is.na(smoking_status),
    !is.na(age),
    !is.na(hypertension),
    !is.na(heart_disease),
    !is.na(stroke)
  ) %>%
  mutate(
    smoking_status = factor(smoking_status)
  )

# Set reference category
medical_data$smoking_status <- relevel(
  medical_data$smoking_status,
  ref = "never smoked"
)

# Check records used in regression
cat(
  "Records used in medical regression:",
  nrow(medical_data),
  "\n"
)

# Multiple logistic regression
medical_model <- glm(
  stroke ~ age + hypertension + heart_disease + smoking_status,
  data = medical_data,
  family = binomial
)

print(summary(medical_model))

# Calculate odds ratios and 95% confidence intervals
model_results <- data.frame(
  variable = names(coef(medical_model)),
  
  odds_ratio = exp(coef(medical_model)),
  
  lower_ci = exp(
    coef(medical_model) -
      1.96 * sqrt(diag(vcov(medical_model)))
  ),
  
  upper_ci = exp(
    coef(medical_model) +
      1.96 * sqrt(diag(vcov(medical_model)))
  )
)

print(model_results)

# ============================================================
# 11. ADJUSTED ODDS RATIOS VISUALIZATION
# ============================================================

# Remove intercept and improve variable names
plot_results <- model_results %>%
  filter(variable != "(Intercept)") %>%
  mutate(
    variable = recode(
      variable,
      "age" = "Age (per year)",
      "hypertension" = "Hypertension",
      "heart_disease" = "Heart Disease",
      "smoking_statusformerly smoked" = "Formerly Smoked",
      "smoking_statussmokes" = "Currently Smokes"
    )
  )

# Create visualization
odds_plot <- ggplot(
  plot_results,
  aes(
    x = reorder(variable, odds_ratio),
    y = odds_ratio
  )
) +
  geom_point(
    size = 3,
    color = "#21618C"
  ) +
  geom_errorbar(
    aes(
      ymin = lower_ci,
      ymax = upper_ci
    ),
    width = 0.15,
    color = "#21618C"
  ) +
  geom_hline(
    yintercept = 1,
    linetype = "dashed",
    color = "gray50"
  ) +
  coord_flip() +
  scale_y_log10() +
  labs(
    title = "Adjusted Odds Ratios for Stroke-Related Factors",
    subtitle = "Multiple logistic regression with 95% confidence intervals",
    x = "Predictor",
    y = "Odds Ratio (log scale)",
    caption = "Source: Stroke Prediction Dataset"
  ) +
  theme_minimal(base_size = 13)

print(odds_plot)

# Save visualization
ggsave(
  "visualizations/adjusted_odds_ratios.png",
  plot = odds_plot,
  width = 11,
  height = 7,
  dpi = 300
)

# ============================================================
# 12. SAVE ANALYSIS RESULTS
# ============================================================

# Save cleaned dataset
write.csv(
  stroke_clean,
  "data/stroke_clean.csv",
  row.names = FALSE
)

# Save age statistics
write.csv(
  age_statistics,
  "results/age_statistics.csv",
  row.names = FALSE
)

# Save medical regression results
write.csv(
  model_results,
  "results/medical_model_results.csv",
  row.names = FALSE
)

# ============================================================
# ANALYSIS COMPLETED
# ============================================================

cat("\nStroke Risk Analysis completed successfully!\n")
cat("All six visualizations have been saved.\n")
cat("Analysis results have been saved as CSV files.\n")