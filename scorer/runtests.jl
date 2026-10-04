# the scorer, pinned; julia scorer/runtests.jl
using Test
include("score.jl")

@testset "killowatt scorer" begin

    @testset "a calm stream never flags" begin
        s = Scorer(; window=24, threshold=3.5, burnin=8)
        flags = String[]
        for i in 1:60
            cents = 100 + (i % 3)   # 100, 101, 102, gentle jitter
            _, _, flag = observe!(s, "acct", "api", Float64(cents))
            push!(flags, flag)
        end
        @test !any(==("anomaly"), flags)
    end

    @testset "a runaway loop flags, after the burn-in" begin
        s = Scorer(; window=24, threshold=3.5, burnin=8)
        for i in 1:20
            observe!(s, "acct", "do", 100.0 + (i % 2))
        end
        scores = [observe!(s, "acct", "do", 5000.0)[1] for _ in 1:3]
        @test all(>(3.5), abs.(scores))
    end

    @testset "one loud service does not poison its neighbours" begin
        s = Scorer(; window=24, threshold=3.5, burnin=8)
        for i in 1:20
            observe!(s, "acct", "loud", 100.0 + (i % 2))
            observe!(s, "acct", "quiet", 50.0 + (i % 2))
        end
        _, _, loud_flag = observe!(s, "acct", "loud", 9000.0)
        _, _, quiet_flag = observe!(s, "acct", "quiet", 51.0)
        @test loud_flag == "anomaly"
        @test quiet_flag == "ok"
    end

    @testset "a constant history treats any move as anomalous" begin
        s = Scorer(; window=24, threshold=3.5, burnin=8)
        for _ in 1:12
            observe!(s, "acct", "flat", 100.0)
        end
        score, _, flag = observe!(s, "acct", "flat", 100.0)
        @test score == 0.0
        @test flag == "ok"
        score2, _, flag2 = observe!(s, "acct", "flat", 900.0)
        @test score2 == 99.0
        @test flag2 == "anomaly"
    end

    @testset "the wire shape survives the round trip" begin
        s = Scorer(; burnin=2)
        line = """{"account":"acme-prod","service":"api","cents":120,"ts_ms":1790812800000}"""
        ev = parse_event(line)
        @test ev.account == "acme-prod"
        @test ev.service == "api"
        @test ev.cents == 120.0

        observe!(s, ev.account, ev.service, ev.cents)
        observe!(s, ev.account, ev.service, ev.cents)
        score, baseline, flag = observe!(s, ev.account, ev.service, ev.cents)
        out = render(line, score, baseline, flag)
        @test occursin("\"score\":", out)
        @test occursin("\"account\":\"acme-prod\"", out)
        @test occursin("\"cents\":120", out)
    end

    @testset "end to end over a stream" begin
        s = Scorer(; window=24, threshold=3.5, burnin=8)
        input = IOBuffer()
        for i in 1:30
            println(input, """{"account":"a","service":"x","cents":100,"ts_ms":$(i * 60000)}""")
        end
        for i in 31:33
            println(input, """{"account":"a","service":"x","cents":5000,"ts_ms":$(i * 60000)}""")
        end
        seekstart(input)
        output = IOBuffer()
        score_stream(input, output, s)
        lines = split(strip(String(take!(output))), "\n")
        @test length(lines) == 33
        @test occursin("\"flag\": \"anomaly\"", lines[33])
        @test !occursin("\"flag\": \"anomaly\"", lines[10])
    end

end
