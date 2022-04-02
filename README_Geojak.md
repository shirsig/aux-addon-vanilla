1. Added auto bid feature, doubled the existing auto buy code and slighly editted
2. Added auto pricing heuristic, these are activate when posting an item with bid price 0, the buyout price works as a minimum
3. Added a keybind for the post button, this significantly speeds up mass posting of items
4. Changed the default post stack size to rand(1,max) instead of always max
5. FIXED TWILLIGHT CULTIST SET NOT DISENCHATABLE
6. use SHagu tweaks vendor values if aux values not avaialbe
7. dont auto bid on own items
8. new filter disenchant-percent and bid-disencahnt-percent
9. enchanting created wands are not encahntabke, same with twillight stuff at 5. reworked implementation for easier addition
10. disenchant values are calcualted from min(value,value_today), this protects users from low enchanting mat prices
11. advanced trade skill menu compabillity to display aux crafting cost
12. changed default post duration from 8 to 24, since turtle wow got no fees anyway