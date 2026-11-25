library(readr); library(dplyr); library(ggplot2); library(tidyr)

d <- read_csv("export/films.csv", show_col_types = FALSE) |>
  filter(!is.na(pub_year), pub_year >= 1930, pub_year <= 2025) |>
  mutate(type = case_when(
    is_sequel               ~ "Sequel",       # includes sequels that are also adaptations
    is_based_on             ~ "Adaptation",   # based on existing work, not a sequel
    TRUE                    ~ "Original"))

cat("films:", nrow(d), " both flags:", sum(d$is_sequel & d$is_based_on), "\n")

roll <- function(x, k = 5) as.numeric(stats::filter(x, rep(1/k, k), sides = 2))
p <- d |> count(pub_year, type) |> complete(pub_year, type, fill = list(n = 0)) |>
  group_by(pub_year) |> mutate(N = sum(n), prob = n / N) |> ungroup() |>
  filter(N >= 30) |> group_by(type) |> arrange(pub_year) |>
  mutate(prob_s = roll(prob)) |> ungroup() |> filter(!is.na(prob_s))

cols <- c(Original = "grey40", Adaptation = "#d95f02", Sequel = "#1b9e77")
g <- ggplot(p, aes(pub_year, prob_s, color = type)) +
  geom_line(linewidth = 1.4) +
  scale_color_manual(values = cols, name = NULL) +
  scale_y_continuous(labels = scales::percent, limits = c(0, 1)) +
  scale_x_continuous(breaks = seq(1930, 2020, 10)) +
  labs(title = "What would a naive investor expect your pitch to be?",
       subtitle = "Share of films released each year by type (5-year moving average); mutually exclusive categories",
       x = "Year of pitch / release", y = "Probability") +
  theme_minimal(base_size = 12) + theme(legend.position = "top")
ggsave("analysis/pitch_probability.png", g, width = 10, height = 6, dpi = 150)

print(p |> filter(pub_year %in% seq(1930, 2020, 10)) |> select(pub_year, type, prob = prob_s) |>
        mutate(prob = round(prob, 3)) |> pivot_wider(names_from = type, values_from = prob) |> as.data.frame())
print(d |> filter(pub_year >= 2020) |> count(type) |> mutate(p = round(n/sum(n),3)) |> as.data.frame())
