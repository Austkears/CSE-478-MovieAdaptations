library(readr); library(dplyr); library(ggplot2); library(tidyr)

d <- read_csv("export/films.csv", show_col_types = FALSE) |>
  filter(!is.na(pub_year), pub_year >= 1930, pub_year <= 2025) |>
  mutate(type = case_when(is_sequel ~ "Sequel", is_based_on ~ "Adaptation", TRUE ~ "Original"))

# "Big project" = top 25% within its own release year (handles inflation / era differences)
top_q <- function(df, col, min_n, from) {
  df |> filter(!is.na(.data[[col]]), pub_year >= from) |>
    group_by(pub_year) |> filter(n() >= min_n, .data[[col]] >= quantile(.data[[col]], 0.75)) |> ungroup()
}
# pooled 5-year window: sum counts over window, then divide (stabilises small years)
probs <- function(df, label) {
  df |> count(pub_year, type) |> complete(pub_year, type, fill = list(n = 0)) |>
    group_by(type) |> arrange(pub_year) |>
    mutate(nw = as.numeric(stats::filter(n, rep(1, 5), sides = 2))) |> ungroup() |>
    group_by(pub_year) |> mutate(prob = nw / sum(nw), Nw = sum(nw)) |> ungroup() |>
    filter(!is.na(prob)) |> mutate(def = label)
}

box  <- top_q(d, "box_office", 40, 1960)
site <- top_q(d, "sitelinks",  100, 1930)
cat("box-office top25% films:", nrow(box), " sitelinks top25% films:", nrow(site), "\n")

p <- bind_rows(probs(box,  "Top 25% by box office (from 1960)"),
               probs(site, "Top 25% by Wikipedia sitelinks (popularity)"))

cols <- c(Original = "grey40", Adaptation = "#d95f02", Sequel = "#1b9e77")
g <- ggplot(p, aes(pub_year, prob, color = type)) +
  geom_line(linewidth = 1.3) +
  facet_wrap(~def, ncol = 1) +
  scale_color_manual(values = cols, name = NULL) +
  scale_y_continuous(labels = scales::percent, limits = c(0, 1)) +
  scale_x_continuous(breaks = seq(1930, 2020, 10)) +
  labs(title = "Pitching a big project: what do the winners look like?",
       subtitle = "Share by type among each year's top-25% films (5-year pooled window)",
       x = "Year", y = "Probability") +
  theme_minimal(base_size = 12) + theme(legend.position = "top")
ggsave("analysis/pitch_probability_big.png", g, width = 10, height = 9, dpi = 150)

print(p |> filter(pub_year %in% seq(1940, 2020, 10)) |> mutate(prob = round(prob, 3)) |>
        select(def, pub_year, type, prob) |> pivot_wider(names_from = type, values_from = prob) |> as.data.frame())
print(bind_rows(box |> mutate(def="box"), site |> mutate(def="site")) |> filter(pub_year >= 2015) |>
        count(def, type) |> group_by(def) |> mutate(p = round(n/sum(n),3)) |> as.data.frame())
