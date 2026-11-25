library(readr); library(dplyr); library(ggplot2); library(tidyr)

d <- read_csv("export/films.csv", show_col_types = FALSE) |>
  filter(!is.na(pub_year), pub_year >= 1930, pub_year <= 2025) |>
  mutate(type = case_when(is_sequel ~ "Sequel", is_based_on ~ "Adaptation", TRUE ~ "Original"),
         type = factor(type, c("Original", "Adaptation", "Sequel")))

# Exponential (powers-of-10) tiers
tiers <- function(x) cut(x, c(0, 1e6, 1e7, 1e8, 1e9, Inf), right = FALSE,
  labels = c("<$1M", "$1M-10M", "$10M-100M", "$100M-1B", ">$1B"))
d$bo_tier <- tiers(d$box_office); d$bud_tier <- tiers(d$budget)

summ <- function(df, tier, era) {
  df |> filter(!is.na({{tier}}), !is.na({{era}})) |> count({{tier}}, {{era}}, type) |>
    complete({{tier}}, {{era}}, type, fill = list(n = 0)) |>
    group_by({{tier}}, {{era}}) |> mutate(N = sum(n), prob = n / N) |> ungroup()
}
cols <- c(Original = "grey40", Adaptation = "#d95f02", Sequel = "#1b9e77")

# (1) Pooled across all years: P(type | box-office tier) and P(type | budget tier)
pool <- bind_rows(
  d |> filter(!is.na(bo_tier)) |> count(tier = bo_tier, type) |> mutate(basis = "Box office"),
  d |> filter(!is.na(bud_tier)) |> count(tier = bud_tier, type) |> mutate(basis = "Budget (n=225)")) |>
  group_by(basis, tier) |> mutate(N = sum(n), prob = n / N) |> ungroup() |> filter(N >= 10)
print(pool |> select(basis, tier, type, n, N, prob) |> mutate(prob = round(prob, 3)) |> as.data.frame())

g1 <- ggplot(pool, aes(tier, prob, color = type, group = type)) +
  geom_line(linewidth = 1.3) + geom_point(size = 2.5) +
  geom_text(data = distinct(pool, basis, tier, N), aes(tier, 1.02, label = paste0("n=", N)),
            inherit.aes = FALSE, size = 3, color = "grey30") +
  facet_wrap(~basis, scales = "free_x") +
  scale_color_manual(values = cols, name = NULL) +
  scale_y_continuous(labels = scales::percent, limits = c(0, 1.05)) +
  labs(title = "Project scale changes the odds: P(type | scale tier)",
       subtitle = "Tiers on an exponential (powers-of-10) scale; all years pooled", x = NULL, y = "Probability") +
  theme_minimal(base_size = 12) + theme(legend.position = "top")
ggsave("analysis/tiers_pooled.png", g1, width = 11, height = 5.5, dpi = 150)

# (2) Tier x era (box office): has the tier mix shifted over time?
d$era <- cut(d$pub_year, c(1959, 1979, 1989, 1999, 2009, 2019, 2025),
             labels = c("1960-79", "1980s", "1990s", "2000s", "2010s", "2020s"))
te <- summ(d |> filter(!is.na(bo_tier)), bo_tier, era) |> filter(N >= 15)
print(te |> filter(type == "Sequel") |> mutate(prob = round(prob, 3)) |> select(bo_tier, era, N, seq_prob = prob) |> as.data.frame())
g2 <- ggplot(te, aes(era, prob, color = type, group = type)) +
  geom_line(linewidth = 1.2) + geom_point(size = 2) +
  facet_wrap(~bo_tier, nrow = 1) +
  scale_color_manual(values = cols, name = NULL) +
  scale_y_continuous(labels = scales::percent, limits = c(0, 1)) +
  labs(title = "P(type | box-office tier) over eras",
       subtitle = "Cells with fewer than 15 films hidden", x = NULL, y = "Probability") +
  theme_minimal(base_size = 11) + theme(legend.position = "top", axis.text.x = element_text(angle = 45, hjust = 1))
ggsave("analysis/tiers_by_era.png", g2, width = 13, height = 5, dpi = 150)
