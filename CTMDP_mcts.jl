module CTMDP_mcts

using pattern
using RewardFun
using MCTS

mctsRng = MersenneTwister(1)

function rollOutPolicy(s::SType, rngState::AbstractRNG)
    return pattern.g_noaction::MCTS.Action #our roll-out policy is the silent policy
end

#TODO:
#Since we are using Monte-Carlo, we might be able to use the history
#and actually handle non-exponential time distributions?
function findFirsti(Snow::SType, trantimes::typeof(pattern.teaTime), rngState::AbstractRNG)
    #Find which state will transition
    N = length(Snow)

    tmin = Inf
    ifirst = 1
    for i in 1:N
       t = -trantimes[Snow[i]] * log(1-rand(rngState))
       if t < tmin
         ifirst = i
         tmin = t
       end
    end
    
    return ifirst
end


function getNextState!(Snew::SType, Snow::SType, a::typeof(pattern.g_noaction), rngState::AbstractRNG)
    #Only transition the one with the earliest event in the race!
    ifirst = findFirsti(Snow, pattern.teaTime, rngState)
    
    for i in 1:length(Snew)
        if i == ifirst
            Snew[ifirst] = randomChoice(Snow[ifirst], a[1] == ifirst, a[2], rngState)
        else
            Snew[i] = Snow[i] 
        end
    end
#     
    return nothing
end

function getReward(S::SType, a::typeof(pattern.g_noaction), pars::MCTS.SPWParams)    
    #assert(pars.β < 0.9f0) #We make the assumption that action cost is small relative to collision cost
    
    R = Reward(S, a, pars.β::Float32)
    
    pars.terminate = false;
    #This is a terminal state...
    if( R <=  RewardFun.collisionCost)
        pars.terminate = true
    end
    return R
end

Afun! = pattern.validActions!

assert (typeof(pattern.g_noaction) == MCTS.Action)
assert (SType == MCTS.State)

function genMCTSdict(d, ec, n, β, γ, resetDict)
    terminate=false#doesnt matter, getReward will update this at each call
    pars = MCTS.SPWParams{MCTS.Action}(terminate, resetDict, d,ec,n,β,γ, 
                Afun!,
                rollOutPolicy,
                getNextState!,
                getReward,
                S2LIDX,
                mctsRng)
    mcts = MCTS.SPW{MCTS.Action}(pars)
    return mcts
end

###############################
#Default parameters
###############################
d = int16(20*pattern.nPhases)           
ec = abs(RewardFun.collisionCost)*5
n = int32(1000)
β = 0.0f0
γ = 0.95f0 ^ (1/pattern.nPhases)

resetDict = true #reset dictionary every cycle

mcts = genMCTSdict(d, ec, n, β, γ, resetDict)

actWorkspace = Array(extActType, pattern.g_nMaxActs)
actWorkspace[1] = copy(pattern.g_noaction)

function mctsPolicy(S::SType)  
    return MCTS.selectAction!(mcts, actWorkspace, S)
end

function testPolicy(S::SType)
    return mcts.pars.β 
end

function loadMCTSPolicy(β::Float32)
    mcts.pars.β = β
    return mctsPolicy
end

export mcts, mctsPolicy, loadMCTSPolicy

# const S = [:LD2, :RB1, :R, :U1]
#  
# function test(S, n)
#      for lo in 1:n 
#          mctsPolicy(S) 
#      end
#  end
#  
# @time test(S,1)
# @time test(S,10)

end