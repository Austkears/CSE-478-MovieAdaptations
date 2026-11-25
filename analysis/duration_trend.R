library(readr); library(dplyr); library(ggplot2); library(tidyr)

d <- read_csv("export/films.csv", show_col_types = FALSE) |>
  filter(!is.na(pub_year), !is.na(duration_min),
         duration_min >= 40, duration_min <= 300,   # drop shorts / data errors
         pub_year >= 1910, pub_year <= 2025)

cat("films used:", nrow(d), "\n")

scatter <- function(flag, title, col) {
  d |> mutate(g = ifelse(.data[[flag]], "TRUE", "FALSE")) |>
    arrange(g) |>                     # draw TRUE on top
    ggplot(aes(pub_year, duration_min, color = g)) +
    geom_point(alpha = 0.25, size = 0.7) +
    geom_smooth(method = "gam", formula = y ~ s(x, bs = "cs"), se = FALSE, linewidth = 1.2) +
    scale_color_manual(values = c("FALSE" = "grey55", "TRUE" = col), name = flag) +
    guides(color = guide_legend(override.aes = list(alpha = 1, size = 2))) +
    labs(title = title, x = "Release year", y = "Duration (min)") +
    theme_minimal(base_size = 12)
}

p1 <- scatter("is_based_on", "Film duration over time: adaptations (is_based_on)", "#d95f02")
p2 <- scatter("is_sequel",   "Film duration over time: sequels/remakes (is_sequel)", "#1b9e77")
ggsave("analysis/scatter_is_based_on.png", p1, width = 10, height = 6, dpi = 150)
ggsave("analysis/scatter_is_sequel.png",   p2, width = 10, height = 6, dpi = 150)

# Median duration per decade by group + share of films per decade
dec <- d |> mutate(decade = floor(pub_year / 10) * 10) |>
  pivot_longer(c(is_based_on, is_sequel), names_to = "flag", values_to = "val")
med <- dec |> group_by(decade, flag, val) |>
  summarise(median = median(duration_min), n = n(), .groups = "drop") |> filter(n >= 20)
p3 <- ggplot(med, aes(decade, median, color = val)) + geom_line() + geom_point() +
  facet_wrap(~flag) + scale_color_manual(values = c("FALSE"="grey55","TRUE"="#d95f02")) +
  labs(title = "Median duration by decade", x = "Decade", y = "Median minutes", color = "flag") +
  theme_minimal(base_size = 12)
ggsave("analysis/median_by_decade.png", p3, width = 10, height = 5, dpi = 150)

# Does duration relate to P(adapt/sequel)? Logistic fit with year control
for (f in c("is_based_on", "is_sequel")) {
  m <- glm(reformulate(c("duration_min", "pub_year"), f), data = d, family = binomial)
  cat("\n==", f, "~ duration + year ==\n"); print(round(summary(m)$coefficients, 4))
}
print(med |> filter(val) |> arrange(flag, decade) |> as.data.frame())
print(dec |> group_by(flag, val) |> summarise(median = median(duration_min), mean = mean(duration_min), n = n(), .groups="drop") |> as.data.frame())

# ---- Zoomed versions: focus on 1930-2025, 70-140 min, with yearly medians + IQR ----
zoom <- function(flag, title, col) {
  dd <- d |> filter(pub_year >= 1930) |> mutate(g = .data[[flag]])
  yr <- dd |> group_by(pub_year, g) |>
    summarise(med = median(duration_min), q1 = quantile(duration_min, .25),
              q3 = quantile(duration_min, .75), n = n(), .groups = "drop") |> filter(n >= 5)
  ggplot() +
    geom_jitter(data = arrange(dd, g), aes(pub_year, duration_min, color = g),
                alpha = 0.12, size = 0.5, width = 0.4, height = 0.5) +
    geom_ribbon(data = yr, aes(pub_year, ymin = q1, ymax = q3, fill = g), alpha = 0.2) +
    geom_line(data = yr, aes(pub_year, med, color = g), linewidth = 1.2) +
    scale_color_manual(values = c("FALSE" = "grey45", "TRUE" = col), name = flag) +
    scale_fill_manual(values = c("FALSE" = "grey45", "TRUE" = col), name = flag) +
    guides(color = guide_legend(override.aes = list(alpha = 1, size = 2))) +
    coord_cartesian(xlim = c(1930, 2025), ylim = c(70, 140)) +
    scale_x_continuous(breaks = seq(1930, 2020, 10)) + scale_y_continuous(breaks = seq(70, 140, 10)) +
    labs(title = title, subtitle = "Lines = yearly median, band = interquartile range (25-75%)",
         x = "Release year", y = "Duration (min)") +
    theme_minimal(base_size = 12)
}
ggsave("analysis/zoom_is_based_on.png", zoom("is_based_on", "Duration over time (zoomed): adaptations", "#d95f02"), width = 10, height = 6, dpi = 150)
ggsave("analysis/zoom_is_sequel.png",   zoom("is_sequel",   "Duration over time (zoomed): sequels", "#1b9e77"), width = 10, height = 6, dpi = 150)

# ---- Clean version: no scatter, centered 5-year rolling median-of-medians ----
roll <- function(x, k = 5) stats::filter(x, rep(1/k, k), sides = 2) |> as.numeric()
clean <- function(flag, title, col) {
  dd <- d |> filter(pub_year >= 1930) |> mutate(g = .data[[flag]])
  yr <- dd |> group_by(pub_year, g) |>
    summarise(med = median(duration_min), q1 = quantile(duration_min, .25),
              q3 = quantile(duration_min, .75), n = n(), .groups = "drop") |>
    filter(n >= 10) |> group_by(g) |> arrange(pub_year) |>
    mutate(across(c(med, q1, q3), roll, .names = "{.col}_s")) |> ungroup() |> filter(!is.na(med_s))
  ggplot(yr, aes(pub_year, color = g, fill = g)) +
    geom_ribbon(aes(ymin = q1_s, ymax = q3_s), alpha = 0.15, color = NA) +
    geom_line(aes(y = med_s), linewidth = 1.3) +
    scale_color_manual(values = c("FALSE" = "grey45", "TRUE" = col), name = flag) +
    scale_fill_manual(values = c("FALSE" = "grey45", "TRUE" = col), name = flag) +
    coord_cartesian(xlim = c(1930, 2025), ylim = c(75, 125)) +
    scale_x_continuous(breaks = seq(1930, 2020, 10)) + scale_y_continuous(breaks = seq(75, 125, 5)) +
    labs(title = title, subtitle = "5-year moving average of yearly median; band = moving average of IQR (years with n<10 dropped)",
         x = "Release year", y = "Duration (min)") +
    theme_minimal(base_size = 12)
}
ggsave("analysis/smooth_is_based_on.png", clean("is_based_on", "Duration trend: adaptations vs. non-adaptations", "#d95f02"), width = 10, height = 6, dpi = 150)
ggsave("analysis/smooth_is_sequel.png",   clean("is_sequel",   "Duration trend: sequels vs. non-sequels", "#1b9e77"), width = 10, height = 6, dpi = 150)
