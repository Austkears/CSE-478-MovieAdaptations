// Set the dimensions of the canvas / graph

const margin = {top: 10, right: 20, bottom: 50, left: 50};
const width = 800 - margin.left - margin.right;
const height = 1000 - margin.top - margin.bottom;

// append the svg object to the center of the page
// append a g (group) element to 'svg' and
// move the g element to the top+left margin
var svg = d3.select(".center").append("svg")
            .attr("width", width + margin.left + margin.right)
            .attr("height", height + margin.top + margin.bottom);

const radius = 100;
var pieChart = svg.append("g")
            .attr("transform", `translate(${margin.left + 2*radius + 25},${margin.top + 2*radius + 25})`);
var gBar = svg.append("g")
            .attr("transform", `translate(${margin.left + 2*radius + 25},${margin.top + 4*radius + 50})`);

const toolTip = d3.select("body").append("div")
  .attr("class", "tooltip")
  .style("position", "absolute")
  .style("pointer-events", "none")
  .style("opacity", 0);

//Pie chart with mouse hover effects
d3.csv('query.csv').then(data => {
    const scaffold = [
        { is_basedOn: "TRUE", count: 0 },
        { is_basedOn: "FALSE",   count: 0 },
    ];
    const counts = d3.rollup(data, v => v.length, d => d.is_basedOn);
    // Merge into scaffold so both slices always exist
    const dataValues = scaffold.map(s => ({
        ...s,
        count: counts.get(s.is_basedOn) ?? 0,
    }));
    console.log(dataValues);
    const pie = d3.pie().value(d => d.count).sort(null);
    const pieData = pie(dataValues);

    const arc = d3.arc()
        .innerRadius(0)
        .outerRadius(radius);

    pieChart.selectAll("path")
        .data(pieData)
        .enter()
        .append("path")
        .attr('class', function (d){ return `pie${d.data.is_basedOn}`})
        .attr("stroke", "black")
        .attr("stroke-width", 2)
        .attr("d", arc)
        .attr("fill", (d, i) => d3.schemeCategory10[i])
        .on("mouseover", (event, d) => {
            const p = pieChart.selectAll(`.pie${d.data.is_basedOn}`);
            var fillStyle = p.style("fill"); 

            // Parse the color into an RGB object
            var color = d3.color(fillStyle);

            p.attr("fill", `rgb(${color.r + 10}, ${color.g + 10}, ${color.b + 10})`)
                .attr("stroke-width", 3);
            toolTip.transition().duration(200).style("opacity", 0.8);
            toolTip
                .style("left", (event.pageX) + "px")
                .style("top",  (event.pageY - 30) + "px")
                .html(`Based On: <b>${d.data.is_basedOn}</b><br>Count: ${d.data.count}`);
            })
        .on("mousemove", (event, d) => {
            toolTip
                .style("left", (event.pageX) + "px")
                .style("top",  (event.pageY - 30) + "px");
            })
        .on("mouseout", (event, d) => {
            const p = pieChart.selectAll(`.pie${d.data.is_basedOn}`);
            var fillStyle = p.style("fill"); 

            // Parse the color into an RGB object
            var color = d3.color(fillStyle);

            p.attr("fill", `rgb(${color.r - 10}, ${color.g - 10}, ${color.b - 10})`)
            .attr("stroke-width", 2);
            toolTip.transition().duration(200).style("opacity", 0);
        });
});

d3.csv('query.csv').then(data =>{
    const scaffold = [
        { sequelOrMore: "TRUE", count: 0 },
        { sequelOrMore: "FALSE", count: 0 },
    ];
    const counts = d3.rollup(data, v => v.length, d => d.sequelOrMore);
    // Merge into scaffold so both slices always exist
    const dataValues = scaffold.map(s => ({
        ...s,
        count: counts.get(s.sequelOrMore) ?? 0,
    }));
    console.log(dataValues);
    const pie = d3.pie().value(d => d.count).sort(null);
    const pieData = pie(dataValues);

    const arc = d3.arc()
        .innerRadius(0)
        .outerRadius(100);

    gBar.selectAll("path")
        .data(pieData)
        .enter()
        .append("path")
        .attr("d", arc)
        .attr("fill", (d, i) => d3.schemeCategory10[i])
        .on("mouseover", (event, d) => {
            toolTip.transition().duration(200).style("opacity", 0.8);
            toolTip
                .style("left", (event.pageX) + "px")
                .style("top",  (event.pageY - 30) + "px")
                .html(`Sequel?: <b>${d.data.sequelOrMore}</b><br>Count: ${d.data.count}`);
            })
        .on("mousemove", (event, d) => {
            toolTip
                .style("left", (event.pageX) + "px")
                .style("top",  (event.pageY - 30) + "px");
            })
        .on("mouseout", () => {
            toolTip.transition().duration(200).style("opacity", 0);
    });
});

svg = d3.select(".center2").append("svg")
            .attr("width", width + margin.left + margin.right)
            .attr("height", height + margin.top + margin.bottom);

d3.csv('query.csv').then(data => {
  svg = svg.append('g').attr("transform", "translate(40, 30)")
  // 1. Coerce pubYear to number (CSV gives strings)
  data.forEach(d => d.pubYear = +d.pubYear);

  // 2. Build one record per year with counts and percent
  const byYear = d3.rollup(
    data,
    rows => {
      const c = d3.rollup(rows, v => v.length, d => d.is_basedOn);
      const t = (c.get("TRUE") ?? 0) + (c.get("FALSE") ?? 0);
      return {
        year: rows[0].pubYear,
        TRUE:  (c.get("TRUE")  ?? 0),
        FALSE: (c.get("FALSE") ?? 0),
        percentTRUE: t ? ((c.get("TRUE") ?? 0) / t) * 100 : 0
      };
    },
    d => d.pubYear
  );

  console.log(byYear)
  // Sorted array of {year, TRUE, FALSE, percentTRUE}
  const yearsArray = Array.from(byYear.values())
    .sort((a, b) => a.year - b.year);

  // 3. Scales
  const x = d3.scaleLinear()
    .domain(d3.extent(yearsArray, d => d.year))
    .range([0, width]);

  // After building yearsArray with {year, TRUE, FALSE, percentTRUE}
    yearsArray.forEach(d => {
    d.percentTRUE  = d.percentTRUE ?? 0;
    d.percentFALSE = 100 - d.percentTRUE;
    });

    const series = d3.stack()
    .keys(["percentTRUE", "percentFALSE"])
    .value((d, key) => d[key])
    (yearsArray);
    
    const y = d3.scaleLinear()
    .domain([0, 100])            // ✅ always 0–100
    .range([height/2, 0]);
    
    svg.append("g")
    .attr("transform", `translate(0, ${height/2})`)
    .call(d3.axisBottom(x).ticks(5).tickFormat(d3.format("d")));

    svg.append("g").call(d3.axisLeft(y).tickFormat(d => d + "%"));

    const color = d3.scaleOrdinal()
    .domain(["percentTRUE", "percentFALSE"])
    .range(["#1ae442", "#b83737"]);

    svg.selectAll("path.layer")
    .data(series)
    .join("path")
        .attr("fill", s => color(s.key))
        .attr("d", d3.area()
        .x(d => x(d.data.year))
        .y0(d => y(d[0]))
        .y1(d => y(d[1]))
        );
});