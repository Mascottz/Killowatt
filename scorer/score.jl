# killowatt anomaly scorer; julia, stdlib only.
#
# usage;
#   julia scorer/score.jl metering/sample-bill.jsonl
#   cat events.jsonl | julia scorer/score.jl
#
# reads usage events in the wire shape, one json object per line, and
# writes the same events back with a robust anomaly score per account and
# service. the score is the modified z-score; the current event measured
# against the median and mad of its own recent history. no floats touch
# money on the way in; cents stay integers, the score rides alongside.
#
# options, as trailing arguments;
#   --window N      history length per account and service, default 24
#   --threshold T   abs score at or above which an event flags, default 3.5
#   --burnin N      events to see before scoring starts, default 8

using Statistics: median

const DEFAULT_WINDOW = 24
const DEFAULT_THRESHOLD = 3.5
const DEFAULT_BURNIN = 8

# the wire shape is ours and the keys are simple identifiers, so a targeted
# parse beats pulling in a json dependency for two fields of interest.
function parse_event(line::AbstractString)
    str(k) = let m = match(Regex("\"$k\"\\s*:\\s*\"([^\"]*)\""), line)
        m === nothing ? nothing : m.captures[1]
    end
    num(k) = let m = match(Regex("\"$k\"\\s*:\\s*(-?[0-9]+(?:\\.[0-9]+)?)"), line)
        m === nothing ? nothing : parse(Float64, m.captures[1])
    end

    account = str("account")
    service = str("service")
    cents = num("cents")
    ts = num("ts_ms")
    (account === nothing || service === nothing || cents === nothing) && return nothing
    (account=account, service=service, cents=cents, ts_ms=ts)
end

# modified z-score; 0.6745 is the 0.75th quantile of the standard normal,
# the constant that makes mad-comparable-to-sigma honest. a zero-mad window
# means the history was constant, so any move at all is the anomaly.
function modified_z(x::Float64, history::Vector{Float64})
    med = median(history)
    mad = median(abs.(history .- med))
    if mad < 1e-9
        return abs(x - med) < 1e-9 ? 0.0 : 99.0
    end
    0.6745 * (x - med) / mad
end

mutable struct Scorer
    window::Int
    threshold::Float64
    burnin::Int
    histories::Dict{Tuple{String,String},Vector{Float64}}
end

Scorer(; window=DEFAULT_WINDOW, threshold=DEFAULT_THRESHOLD, burnin=DEFAULT_BURNIN) =
    Scorer(window, threshold, burnin, Dict{Tuple{String,String},Vector{Float64}}())

# returns (score, baseline, flag) for one event and updates the history.
function observe!(s::Scorer, account::AbstractString, service::AbstractString, cents::Float64)
    key = (account, service)
    history = get!(s.histories, key, Float64[])

    if length(history) < s.burnin
        push!(history, cents)
        length(history) > s.window && popfirst!(history)
        return (0.0, cents, "warming")
    end

    score = modified_z(cents, history)
    baseline = median(history)
    flag = abs(score) >= s.threshold ? "anomaly" : "ok"

    push!(history, cents)
    length(history) > s.window && popfirst!(history)

    (round(score, digits=2), baseline, flag)
end

function render(line::AbstractString, score::Float64, baseline::Float64, flag::String)
    body = strip(line)
    body = endswith(body, "}") ? body[1:end-1] : body
    baseline_cents = round(Int, baseline)
    "$body, \"score\": $score, \"baseline_cents\": $baseline_cents, \"flag\": \"$flag\"}"
end

function score_stream(input::IO, output::IO, s::Scorer)
    for line in eachline(input)
        stripped = strip(line)
        isempty(stripped) && continue
        ev = parse_event(stripped)
        if ev === nothing
            println(output, stripped)
            continue
        end
        score, baseline, flag = observe!(s, ev.account, ev.service, ev.cents)
        println(output, render(stripped, score, baseline, flag))
    end
end

function parse_args(args)
    opts = Dict(:window => DEFAULT_WINDOW, :threshold => DEFAULT_THRESHOLD, :burnin => DEFAULT_BURNIN)
    files = String[]
    i = 1
    while i <= length(args)
        a = args[i]
        if a == "--window"
            opts[:window] = parse(Int, args[i+1]); i += 2
        elseif a == "--threshold"
            opts[:threshold] = parse(Float64, args[i+1]); i += 2
        elseif a == "--burnin"
            opts[:burnin] = parse(Int, args[i+1]); i += 2
        else
            push!(files, a); i += 1
        end
    end
    (opts=opts, files=files)
end

if abspath(PROGRAM_FILE) == @__FILE__
    parsed = parse_args(ARGS)
    scorer = Scorer(;
        window=parsed.opts[:window],
        threshold=parsed.opts[:threshold],
        burnin=parsed.opts[:burnin],
    )
    input = isempty(parsed.files) ? stdin : open(first(parsed.files))
    try
        score_stream(input, stdout, scorer)
    finally
        input !== stdin && close(input)
    end
end
