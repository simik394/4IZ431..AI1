# multiAgents.py
# --------------
# Licensing Information:  You are free to use or extend these projects for
# educational purposes provided that (1) you do not distribute or publish
# solutions, (2) you retain this notice, and (3) you provide clear
# attribution to UC Berkeley, including a link to http://ai.berkeley.edu.
# 
# Attribution Information: The Pacman AI projects were developed at UC Berkeley.
# The core projects and autograders were primarily created by John DeNero
# (denero@cs.berkeley.edu) and Dan Klein (klein@cs.berkeley.edu).
# Student side autograding was added by Brad Miller, Nick Hay, and
# Pieter Abbeel (pabbeel@cs.berkeley.edu).


from util import manhattanDistance
from game import Directions
import random, util

from game import Agent
from pacman import GameState

class ReflexAgent(Agent):
    """
    A reflex agent chooses an action at each choice point by examining
    its alternatives via a state evaluation function.

    The code below is provided as a guide.  You are welcome to change
    it in any way you see fit, so long as you don't touch our method
    headers.
    """


    def getAction(self, gameState: GameState):
        """
        You do not need to change this method, but you're welcome to.

        getAction chooses among the best options according to the evaluation function.

        Just like in the previous project, getAction takes a GameState and returns
        some Directions.X for some X in the set {NORTH, SOUTH, WEST, EAST, STOP}
        """
        # Collect legal moves and successor states
        legalMoves = gameState.getLegalActions()

        # Choose one of the best actions
        scores = [self.evaluationFunction(gameState, action) for action in legalMoves]
        bestScore = max(scores)
        bestIndices = [index for index in range(len(scores)) if scores[index] == bestScore]
        chosenIndex = random.choice(bestIndices) # Pick randomly among the best

        "Add more of your code here if you want to"

        return legalMoves[chosenIndex]

    def evaluationFunction(self, currentGameState: GameState, action):
        """
        Design a better evaluation function here.

        The evaluation function takes in the current and proposed successor
        GameStates (pacman.py) and returns a number, where higher numbers are better.

        The code below extracts some useful information from the state, like the
        remaining food (newFood) and Pacman position after moving (newPos).
        newScaredTimes holds the number of moves that each ghost will remain
        scared because of Pacman having eaten a power pellet.

        Print out these variables to see what you're getting, then combine them
        to create a masterful evaluation function.
        """
        # Useful information you can extract from a GameState (pacman.py)
        successorGameState = currentGameState.generatePacmanSuccessor(action)
        newPos = successorGameState.getPacmanPosition()
        newFood = successorGameState.getFood()
        newGhostStates = successorGameState.getGhostStates()
        newScaredTimes = [ghostState.scaredTimer for ghostState in newGhostStates]

        "*** YOUR CODE HERE ***"

        from game import Actions
        
        # --- 1. DATA SNAPSHOT ---
        # Získáme budoucí stav
        successorGameState = currentGameState.generatePacmanSuccessor(action)
        newPos = successorGameState.getPacmanPosition()
        newPosInt = (int(newPos[0]), int(newPos[1]))
        
        # Grid objekty
        walls = currentGameState.getWalls()
        food = successorGameState.getFood()
        ghosts = successorGameState.getGhostStates()
        
        width = walls.width
        height = walls.height
        
        # Base Score: Obsahuje +10 za jídlo snědené tímto tahem
        total_score = successorGameState.getScore()

        # ---------------------------------------------------------------------
        # VRSTVA 1: "SCENT MAP" (Difúzní Matice)
        # Toto řeší zdi, blízké duchy a pasti automaticky.
        # ---------------------------------------------------------------------
        
        heat_map = [[0.0 for y in range(height)] for x in range(width)]
        
        # A. INJEKCE NEBEZPEČÍ (Duchové s Vektorovou Predikcí)
        active_ghost_nearby = False
        
        for ghost in ghosts:
            g_pos = ghost.getPosition()
            igx, igy = int(g_pos[0]), int(g_pos[1])
            
            # Vzdálenost k Pacmanovi (pro rozhodování o logice)
            dist_to_pac = manhattanDistance(newPos, g_pos)

            if ghost.scaredTimer > 0:
                # LOV: Vyděšený duch je masivní zdroj pozitivního signálu
                if 0 <= igx < width and 0 <= igy < height:
                    heat_map[igx][igy] += 100.0
            else:
                # ÚTĚK: Aktivní duch
                if dist_to_pac < 5: active_ghost_nearby = True
                
                # Vektorová analýza záměru (Dot Product)
                ghost_dir = Actions.directionToVector(ghost.getDirection())
                to_pacman = (newPos[0] - g_pos[0], newPos[1] - g_pos[1])
                dot_prod = (ghost_dir[0] * to_pacman[0]) + (ghost_dir[1] * to_pacman[1])
                
                # Modulace intenzity zápachu
                if dot_prod > 0:
                    intensity = -5000.0 # AGRESIVNÍ: Jde po nás -> Černá díra
                else:
                    intensity = -200.0  # PASIVNÍ: Jde pryč -> Mírný chlad
                
                # Vložíme do mapy (i do okolí, pro jistotu)
                if 0 <= igx < width and 0 <= igy < height:
                    heat_map[igx][igy] += intensity

        # B. DIFÚZE (Šíření signálu přes chodby)
        # Stačí 2-3 iterace. Signál "oteče" zdi a dostane se k Pacmanovi jen pokud je cesta.
        # Pokud je duch za zdí, signál klesne téměř na nulu.
        ITERATIONS = 2
        DECAY = 0.6
        
        # Pracovní mřížka pro výpočet
        for _ in range(ITERATIONS):
            new_grid = [row[:] for row in heat_map] # Copy
            for x in range(1, width - 1):
                for y in range(1, height - 1):
                    if walls[x][y]: continue # Zdi izolují
                    
                    # Pokud je hodnota extrémní (zdroj), neměníme ji
                    if abs(heat_map[x][y]) > 500.0: continue

                    # Průměr ze 4 sousedů
                    neighbor_val = 0
                    valid = 0
                    # Unrolled loop pro rychlost
                    if not walls[x+1][y]: neighbor_val += heat_map[x+1][y]; valid+=1
                    if not walls[x-1][y]: neighbor_val += heat_map[x-1][y]; valid+=1
                    if not walls[x][y+1]: neighbor_val += heat_map[x][y+1]; valid+=1
                    if not walls[x][y-1]: neighbor_val += heat_map[x][y-1]; valid+=1
                    
                    if valid > 0:
                        new_grid[x][y] = (neighbor_val / valid) * DECAY
            heat_map = new_grid

        # Přečteme hodnotu z mapy na pozici Pacmana
        diffusion_value = heat_map[newPosInt[0]][newPosInt[1]]
        
        # Pokud je hodnota kritická, okamžitý return (ušetříme čas)
        if diffusion_value < -500: 
            return -float('inf')
        
        total_score += diffusion_value

        # ---------------------------------------------------------------------
        # VRSTVA 2: GLOBÁLNÍ NAVIGACE (Pokud nehrozí smrt)
        # Difúze má krátký dosah. Pokud je jídlo daleko, použijeme Manhattan.
        # ---------------------------------------------------------------------
        foodList = food.asList()
        if foodList:
            # Rychlá metrika k nejbližšímu jídlu
            min_food_dist = min([manhattanDistance(newPos, f) for f in foodList])
            
            # Zvýšíme váhu, pokud není v okolí aktivní duch (můžeme riskovat/sprintovat)
            weight = 20.0 if not active_ghost_nearby else 5.0
            total_score += weight / (min_food_dist + 1)

            # Extra bonus za snězení jídla (aby se nezasekl těsně vedle)
            # successorGameState.getNumFood() < currentGameState.getNumFood()
            # Toto je už v getScore(), ale zvýraznění neuškodí
            if successorGameState.getNumFood() < currentGameState.getNumFood():
                total_score += 50

        # ---------------------------------------------------------------------
        # VRSTVA 3: TAKTICKÉ KOREKCE
        # ---------------------------------------------------------------------
        
        # Penalizace zastavení 
        if action == Directions.STOP:
            total_score -= 50
            
        # Penalizace "Tunelové smrti" (Dead End Detection)
        # Pokud máme 3 zdi okolo a není tam jídlo, je to past.
        # (Difúze to řeší částečně, ale explicitní kontrola je jistota)
        x, y = newPosInt
        wall_count = 0
        if walls[x+1][y]: wall_count += 1
        if walls[x-1][y]: wall_count += 1
        if walls[x][y+1]: wall_count += 1
        if walls[x][y-1]: wall_count += 1
        
        # Pokud vlezeme do slepé uličky a nehoní nás duch (kdy bychom se tam mohli schovat),
        # a není tam jídlo, tak tam nelezeme.
        if wall_count >= 3 and not diffusion_value < -10:
             # Jemná penalizace, aby tam šel jen pro jídlo
            total_score -= 5 

        return total_score
########  FOR ADVERSIAL SEARCH 
def scoreEvaluationFunction(currentGameState: GameState):
    """
    This default evaluation function just returns the score of the state.
    The score is the same one displayed in the Pacman GUI.

    This evaluation function is meant for use with adversarial search agents
    (not reflex agents).
    """
    return currentGameState.getScore()
######  ABSTRACT CLASS OF MULTIAGENTSEARCH AGENT
class MultiAgentSearchAgent(Agent):
    """
    This class provides some common elements to all of your
    multi-agent searchers.  Any methods defined here will be available
    to the MinimaxPacmanAgent, AlphaBetaPacmanAgent & ExpectimaxPacmanAgent.

    You *do not* need to make any changes here, but you can if you want to
    add functionality to all your adversarial search agents.  Please do not
    remove anything, however.

    Note: this is an abstract class: one that should not be instantiated.  It's
    only partially specified, and designed to be extended.  Agent (game.py)
    is another abstract class.
    """

    def __init__(self, evalFn = 'scoreEvaluationFunction', depth = '2'):
        self.index = 0 # Pacman is always agent index 0
        self.evaluationFunction = util.lookup(evalFn, globals())
        self.depth = int(depth)

###  QUESTION 2  ###
class MinimaxAgent(MultiAgentSearchAgent):
    """
    Your minimax agent (question 2)
    """

    def getAction(self, gameState: GameState):
        """
        Returns the minimax action from the current gameState using self.depth
        and self.evaluationFunction.

        Here are some method calls that might be useful when implementing minimax.

        gameState.getLegalActions(agentIndex):
        Returns a list of legal actions for an agent
        agentIndex=0 means Pacman, ghosts are >= 1

        gameState.generateSuccessor(agentIndex, action):
        Returns the successor game state after an agent takes an action

        gameState.getNumAgents():
        Returns the total number of agents in the game

        gameState.isWin():
        Returns whether or not the game state is a winning state

        gameState.isLose():
        Returns whether or not the game state is a losing state
        """
        "*** YOUR CODE HERE ***"
        # util.raiseNotDefined()
        
        def minimax(agentIndex, depth, state):
            # 1. Terminální stavy (Base Cases)
            # ===================================
            # Pokud hra skončila (výhra/prohra) nebo jsme dosáhli max hloubky
            if state.isWin() or state.isLose() or depth == self.depth:
                return self.evaluationFunction(state)

            # 2. Příprava na další krok
            # ===================================
            # Zjistíme, kdo hraje příště
            numAgents = state.getNumAgents()
            nextAgent = (agentIndex + 1) % numAgents
            
            # Pokud je další na řadě zase Pacman (agent 0), znamená to, 
            # že všichni duchové odehráli -> zvyšujeme hloubku.
            # Poznámka: Zde 'depth' chápeme jako "current depth index".
            nextDepth = depth + 1 if nextAgent == 0 else depth

            # Získáme legální akce pro aktuálního agenta
            legalMoves = state.getLegalActions(agentIndex)

            # 3. Logika Agenta (MAX vs MIN)
            # ===================================
            if agentIndex == 0:
                # --- PACMAN (MAXIMIZER) ---
                max_score = -float('inf')
                for action in legalMoves:
                    successor = state.generateSuccessor(agentIndex, action)
                    score = minimax(nextAgent, nextDepth, successor)
                    if score > max_score:
                        max_score = score
                return max_score
            else:
                # --- DUCHOVÉ (MINIMIZERS) ---
                min_score = float('inf')
                for action in legalMoves:
                    successor = state.generateSuccessor(agentIndex, action)
                    score = minimax(nextAgent, nextDepth, successor)
                    if score < min_score:
                        min_score = score
                return min_score

        # ---- ROOT CALL ----
        # ===================================
        # V kořeni (Root) musíme vrátit AKCI, ne jen skóre.
        # minimax() ale vrací jen skóre, proto je první vrstva spracována "manuálně".
        
        best_score = -float('inf')
        best_action = None
        
        # Pacman (index 0) začíná
        legalMoves = gameState.getLegalActions(0)
        
        for action in legalMoves:
            successor = gameState.generateSuccessor(0, action)
            # Volání rekurze pro prvního ducha (index 1), hloubka stále 0
            score = minimax(1, 0, successor)
            
            # Maximizace v kořeni
            if score > best_score:
                best_score = score
                best_action = action
        
        return best_action
###  QUESTION 3  ###
class AlphaBetaAgent(MultiAgentSearchAgent):
    """
    Your minimax agent with alpha-beta pruning (question 3)
    """

    def getAction(self, gameState: GameState):
        """
        Returns the minimax action using self.depth and self.evaluationFunction
        """
        "*** YOUR CODE HERE ***"
       
        # --- REKURZIVNÍ FUNKCE ---
        def alpha_beta_search(agentIndex, depth, state, alpha, beta):
            # 1. Terminální stavy (Stejné jako Q2)
            # ===================================
            if state.isWin() or state.isLose() or depth == self.depth:
                return self.evaluationFunction(state)

            # Příprava indexů (Stejné jako Q2)
            numAgents = state.getNumAgents()
            nextAgent = (agentIndex + 1) % numAgents
            nextDepth = depth + 1 if nextAgent == 0 else depth
            
            legalMoves = state.getLegalActions(agentIndex)

            # 2. Logika Agenta
            # ===================================
            if agentIndex == 0:
                # --- MAXIMIZER (Pacman) ---
                v = -float('inf')
                for action in legalMoves:
                    successor = state.generateSuccessor(agentIndex, action)
                    v = max(v, alpha_beta_search(nextAgent, nextDepth, successor, alpha, beta))
                    
                    # PRUNING (Prořezání)
                    if v > beta:
                        return v # Duch nám nedovolí víc než beta, končíme
                    
                    # Update Alpha (Pacman našel novou nejlepší spodní hranici)
                    alpha = max(alpha, v)
                return v
            
            else:
                # --- MINIMIZER (Duchové) ---
                v = float('inf')
                for action in legalMoves:
                    successor = state.generateSuccessor(agentIndex, action)
                    # Předáváme alpha a beta dál
                    v = min(v, alpha_beta_search(nextAgent, nextDepth, successor, alpha, beta))
                    
                    # PRUNING (Prořezání)
                    if v < alpha:
                        return v # Pacman nevybere nic horšího než alpha, končíme
                    
                    # Update Beta (Duch našel novou nejlepší horní hranici)
                    beta = min(beta, v)
                return v

        # --- ROOT CALL ---
        # ===================================
        # Tady musíme: 
        #  - vybrat AKCI, ne jen vrátit hodnotu
        #  - aktualizovat alpha/beta i v této smyčce!
        
        best_score = -float('inf')
        best_action = None
        
        # Inicializace mezí pro kořen
        alpha = -float('inf')
        beta = float('inf')
        
        legalMoves = gameState.getLegalActions(0)
        
        for action in legalMoves:
            successor = gameState.generateSuccessor(0, action)
            # Voláme rekurzi pro prvního ducha
            score = alpha_beta_search(1, 0, successor, alpha, beta)
            
            if score > best_score:
                best_score = score
                best_action = action
            
            # Update Alpha v kořeni!
            # (Root je v podstatě MAX uzel, takže aktualizujeme alpha)
            if score > beta: 
                return best_action
            alpha = max(alpha, score)
            
        return best_action
###  QUESTION 4  ###
class ExpectimaxAgent(MultiAgentSearchAgent):
    """
      Your expectimax agent (question 4)
    """

    def getAction(self, gameState: GameState):
        """
        Returns the expectimax action using self.depth and self.evaluationFunction

        All ghosts should be modeled as choosing uniformly at random from their
        legal moves.
        """
        "*** YOUR CODE HERE ***"
        
        
        def expectimax(agentIndex, depth, state):
            # 1. Terminální stavy
            # ===================================
            if state.isWin() or state.isLose() or depth == self.depth:
                return self.evaluationFunction(state)

            # Příprava indexů
            numAgents = state.getNumAgents()
            nextAgent = (agentIndex + 1) % numAgents
            nextDepth = depth + 1 if nextAgent == 0 else depth
            
            legalMoves = state.getLegalActions(agentIndex)
            
            # Pokud nemáme žádné tahy (a není to Win/Lose),legálně nemůžeme nic -> return eval
            if not legalMoves:
                return self.evaluationFunction(state)

            # 2. Logika Agenta
            # ===================================
            if agentIndex == 0:
                # --- MAXIMIZER (Pacman) ---
                # Pacman hraje pořád stejně - chce to nejlepší pro sebe
                max_score = -float('inf')
                for action in legalMoves:
                    successor = state.generateSuccessor(agentIndex, action)
                    score = expectimax(nextAgent, nextDepth, successor)
                    if score > max_score:
                        max_score = score
                return max_score
            
            else:
                # --- EXPECTATION (Duchové) ---
                # Tady je změna! Duchové nehrají optimálně, ale náhodně.
                # Počítáme PRŮMĚR všech možných výsledků.
                total_score = 0.0
                for action in legalMoves:
                    successor = state.generateSuccessor(agentIndex, action)
                    score = expectimax(nextAgent, nextDepth, successor)
                    total_score += score
                
                # Předpokládáme Uniform Distribution (všechny tahy stejně pravděpodobné)
                average_score = total_score / len(legalMoves)
                return average_score

        # --- ROOT CALL ---
        # ===================================
        best_score = -float('inf')
        best_action = None
        
        legalMoves = gameState.getLegalActions(0)
        for action in legalMoves:
            successor = gameState.generateSuccessor(0, action)
            score = expectimax(1, 0, successor)
            
            if score > best_score:
                best_score = score
                best_action = action
        
        return best_action
###  QUESTION 5  ###
def betterEvaluationFunction(currentGameState: GameState):
    """
    Your extreme ghost-hunting, pellet-nabbing, food-gobbling, unstoppable
    evaluation function (question 5).

    DESCRIPTION: <write something here so we know what you did>
    """
    "*** YOUR CODE HERE ***"

      # Abbreviation
better = betterEvaluationFunction
