**Retro RPG World Simulator**.

---

## 1. Project Overview & Scope

The goal is to build a terminal-based, data-structure-driven text RPG engine. The focus is **not** on rich gameplay loops, graphics, or narrative storytelling. The focus is on implementing core computer science data structures and algorithms from scratch, utilizing strict Object-Oriented Programming (OOP) principles, and verifying their algorithmic efficiency ($Big\ O$) through live runtime data.

### System Boundaries

* **Interface:** Standard Terminal I/O (Text commands, printed status logs, and a simple text-based ASCII map representation).
* **Third-Party Libraries:** **None allowed** for core data structures or algorithms. Everything must be built using raw language primitives (pointers, classes/structs, standard arrays).

---

## 2. Functional Requirements

### FR-1: World Traversal (Graph Engine)

* The world consists of distinct "Rooms" connected by directional pathways (North, South, East, West).
* The user must be able to input commands (e.g., `move north`) to change their location.
* Enemies must have the ability to move autonomously between rooms.

### FR-2: Time & Combat System (Priority Queue Engine)

* Time in the game is discrete and tick-based, managed by an action-queue.
* Entities (Player and Monsters) possess a `Speed` attribute.
* The engine must dynamically calculate whose turn it is next based on speed, executing actions in strict order.

### FR-3: Inventory & Economy (Sorting Engine)

* The player has an inventory containing items with properties: Name, Value (Gold), and Weight.
* The player can view their inventory sorted dynamically by different criteria (e.g., sorting by highest value or lowest weight) on command.

### FR-4: Enemy AI Tracking (Pathfinding Engine)

* Monsters can target a player. If a monster decides to hunt the player, it must calculate the shortest path through the room layout and step toward the player's room each tick.

### FR-5: Telemetry & Profiling (The "Proof" Mode)

* Whenever a sorting or pathfinding algorithm runs, the engine must print a **Telemetry Debug Log** showing:
* The size of the data set ($N$).
* The theoretical $Big\ O$ bound.
* The *actual* number of operation steps/comparisons performed during execution.



---

## 3. Technical Design & Architecture (OOP & Data Structures)

We will structure this system using distinct Object-Oriented modules. Below are the custom structures you will build instead of using language defaults.

### A. The Data Structures Layer

| Structure | Custom Class Name | Game Component | Big O Requirement |
| --- | --- | --- | --- |
| **Graph (Adjacency List)** | `WorldGraph` | The Map Layout | Node traversal: $O(V + E)$ |
| **Binary Min-Heap** | `TurnPriorityQueue` | Turn/Action Scheduler | Extract Next: $O(\log N)$, Insert: $O(\log N)$ |
| **Doubly Linked List** | `InventoryList` | Item Inventories | Insertion/Deletion: $O(1)$ |

### B. The Algorithmic Layer

* **QuickSort:** Implemented recursively on the `InventoryList` (or an intermediate array proxy) to arrange items by attributes. Average case: $O(N \log N)$.
* **Dijkstra’s Algorithm:** Implemented to navigate the `WorldGraph`, utilizing your custom `TurnPriorityQueue` as the min-heap structure for optimization. Complexity: $O((V + E) \log V)$.

### C. The Class Hierarchy (OOP Blueprint)

```
                       +-------------------+
                       |    GameEntity     |  (Abstract Base Class)
                       +-------------------+
                       | - id: int         |
                       | - name: string    |
                       | - currentRoom:    |
                       +---------+---------+
                                 |
                +----------------+----------------+
                |                                 |
      +---------v---------+             +---------v---------+
      |      Player       |             |      Monster      |
      +-------------------+             +-------------------+
      | - inventory       |             | - aiState         |
      | + takeAction()    |             | + takeAction()    |
      +-------------------+             +-------------------+

```

* **Encapsulation:** All attributes (`health`, `weight`, `connections`) must be `private` or `protected`. State mutation must happen via explicit methods (e.g., `damage()`, `addItem()`).
* **Polymorphism:** The main game loop will call `takeAction()` on a base `GameEntity` pointer/reference, executing distinct behaviors for players vs. automated monsters.

---
