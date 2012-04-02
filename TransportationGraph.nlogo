globals [point-locations destination-point-locations paths p-labels t-labels counter total-wait-count route1 route2 route3 route4 route5]

breed [vehicles vehicle]
breed [points point]
breed [turn-points turn-point]
directed-link-breed [roads road]

vehicles-own [thrift time-urgency from-point to-point step-required step-taken distance-travelled moving?]
roads-own [has-erp? capacity v-count]

to setup
  ca
  reset-ticks
  resize-world -29 29 -22 22  
  
  draw-points
  draw-roads
  
  set total-wait-count 0
  set counter 0
  
  set route1 0
  set route2 0
  set route3 0
  set route4 0
  set route5 0
  
  import-drawing "map.png"
  
end

to go
  ;;i generate number of vehicles by counter value. one vehicle per go until maximum
  if counter < num-vehicles
  [
    ;;variance of both time-urgency and thriftiness will determine how wide the range of values from 0 to 1 each car will be
    ;;the higher the variance, the wider it will be, spread with specified middle value
    create-vehicles 1 [
      let rand-t (random-float var-thrift)
      let t mid-thrift + rand-t
      if t > 1 [set t mid-thrift - rand-t]
      
      let rand-u (random-float var-urgent)
      let u mid-urgent + rand-u
      if u > 1 [set u mid-urgent - rand-u]
        
      set thrift t
      set time-urgency u
      setxy 23 15
      set shape "car"
      set from-point one-of points with [label = "start"]
      set step-taken 0
      set step-required 0
      set distance-travelled 0
      set moving? false
    ]
  ]
  set counter counter + 1
  
  ask vehicles [
    if not reached-destination? from-point 
    
    [
      if step-taken = 0
      [
        let temp 0
        let prob-time random-float 1
        let prob-thrift random-float 1
        
        ;;if neither happens just random it, otherwise overwrite
        ask from-point [
          set temp one-of out-link-neighbors
        ]
        set to-point temp
        ;;time urgency will determine probability at which the car will choose the shorter distance\
        ;;thriftiness will determine the probability which the car will choose the non-ERP road
        ;;if either variable has higher importance, then it will have priority if both occurs.
        ifelse prob-time <= time-urgency and prob-thrift <= thrift
        [
          ;;do the priority one
          ifelse time-urgency > thrift
          [
            set-shortest-path
          ]
          [
            set-path-of-no-erp
          ]
        ]
        [
          if prob-time <= time-urgency
          [
            ;;do shortest travel route logic
            set-shortest-path
          ]
          if prob-thrift <= thrift
          [
            ;;do thrift logic
            set-path-of-no-erp
          ]
        ]
        
        ;;do a check on all roads from point to point of those that are diversions, if one is full and the other is not, use the alternative.
        ;;first i check if there is a full road.
        let full-road-count 0
        ask from-point 
        [ 
          if count my-out-links = 2
          [
            ask my-out-links
            [
              if v-count >= capacity
              [
                set full-road-count (full-road-count + 1)
              ]
            ]
          ]
        ]
        ;;if only one is full, just set the other as alternative route and go
        
        if full-road-count = 1
        [
          let temp-divert ""
          ask from-point
          [
            ask my-out-links with [v-count < capacity]
            [
              ;;show "alternative chosen"
              set temp-divert end2
            ]
          ]
          set to-point temp-divert
        ]
        ;;face the point and set required distance
        face to-point
        set step-required (distance to-point - 1)

      ]
      ;;------------------------------------------------- VCOUNT starts here
      ifelse step-taken < step-required
      [
        ;;check if there is allowable capacity on the road, if no don't move
        ;;of course only at the start of the node then you do this
        let should-move? moving?
        let temp-cap to-point
        ask from-point 
        [
          ask out-link-to temp-cap
          [
            if v-count < capacity
            [
              if not should-move?
              [
                set v-count v-count + 1
              ]
              set should-move? true
            ]
          ]
        ]
        
        ifelse should-move?
        [
          set moving? true
          fd 1
          set step-taken (step-taken + 1)
          set distance-travelled (distance-travelled + 1)
        ]
        [
          set total-wait-count total-wait-count + 1
          set moving? false
          set should-move? false
        ]
      ]
      [
        set step-taken 0
        ;;upon reaching, release capacity spaces for road
        let temp to-point
        ask from-point 
        [
          ask out-link-to temp
          [
;            if v-count >= capacity
;            [
              set v-count v-count - 1
;            ]
            
          ]
        ]

        set from-point to-point
        set moving? false
        ;;this is meant for the purpose of my counter of cars passing by the route
        let route-count-points ["t2" "t15" "t5" "t17" "t8"]
        let index 0
        while [index < length route-count-points]
        [
          if [label] of to-point = item index route-count-points
          [
            if index = 0
            [
              set route1 route1 + 1
            ]
            if index = 1
            [ 
              set route2 route2 + 1
            ]
            if index = 2
            [
              set route3 route3 + 1
            ]
            if index = 3
            [
              set route4 route4 + 1
            ]
            if index = 4
            [
              set route5 route5 + 1
            ]
          ]
          set index index + 1
        ]
        move-to to-point
       ]

    ]
  ]
  tick
end

to set-path-of-no-erp
  ;;extract out start and end
  let ep-labels p-labels
  set ep-labels remove-item 4 ep-labels
  set ep-labels remove-item 4 ep-labels
  ifelse member? [label] of from-point ep-labels
  [
    ;;if this is a junction point, make erp decision
    ;;we choose the path of no erp
    ;;get the agentset of outlink neighbours, then select link with no erp.
    let temp ""
    let no-erp-link ""
    ask from-point 
    [
      ask my-out-links
      [
        if not has-erp?
        [
          set temp end2
        ]
      ]
      ;;if all are erp, then random
      if temp = ""
      [
        set temp one-of out-link-neighbors
      ]
    ]
    set to-point temp
  ]
  [
    ;;this condition is if the point is a turning point, then just go forward
    let temp ""
    ask from-point [
      set temp one-of out-link-neighbors
    ]
    set to-point temp
  ]  
end

to set-shortest-path

  ;;extract out start and end
  let ep-labels p-labels
  set ep-labels remove-item 4 ep-labels
  set ep-labels remove-item 4 ep-labels
  ifelse member? [label] of from-point ep-labels
  [
    ;;if this is a junction point, make shortest decision
    let temp-dist []
    let comparing-paths []
    foreach paths
    [
      ;;select junction label and compare with from-point label
      ;;if same, then put them in a new array so that we can compare the distance (trimming)
      ;;store temporarily the distances into an array to find minimum for later
      if item 1 ? = [label] of from-point
      [
        set comparing-paths lput ? comparing-paths
        set temp-dist lput item 0 ? temp-dist
      ]
    ]
    ;;now i get the shortest route and assign the to-point value
    let shortest-path []
    foreach comparing-paths
    [
      ;;get out the minimum distance index
      if item 0 ? = min temp-dist
      [
        set shortest-path ?
      ]
    ]
    set to-point one-of points with [label = item 2 shortest-path]
  ]
  [
    ;;this condition is if the point is a turning point, then just go forward
    let temp ""
    ask from-point [
      set temp one-of out-link-neighbors
    ]
    set to-point temp
  ]
end

to-report reached-destination? [point]
  let x 0
  let y 0
  ask point [set x pxcor set y pycor]
  
  let dest-x 0
  let dest-y 0
  ask one-of points with [label = "end"]
  [
    set dest-x pxcor
    set dest-y pycor
  ]
  ifelse dest-x = x and dest-y = y
  [
    report true
  ]
  [
    report false
  ]
end

to draw-points
  set point-locations [
    ;;starting point
    ["start" 23 15]
    
    ;;decision points:
    ["2" 18 7]
    ["3" 0 17]
    ["4" -7 6]
    ["t18" -10 4]
    ["6" -13 14]
    ["t19" -7 22]
    
    ;;end point:
    ["end" -16 -22]
    
    ;;turning points:
    ;;Shenton Way
    ["t1" 5 -14]
    
    ;;Keppel Road
    ["t2" -1 -22]
    ["t3" -10 -22]
    ["t16" -14 -22]
    
    ;;South Bridge Road
    ["t4" -6 7]
    
    ;;Neil Road
    ["t5" -13 3]
    ["t6" -17 -1]
    
    ;;Keong Saik Road
    ["t7" -12 13]
    ["t8" -16 5]
    ["t9" -16 0]
    
    ;;Cantonment Road
    ["t10" -19 -4]
    ["t11" -17 -15]
    
    ;;Tanjong Pagar Road
    ["t12" -8 2]
    ["t13" -7 0]
    ["t14" -8 -4]
    ["t15" -10 -17]
    
    ["t17" -23 3]
  ]
  
  ;;define a selection list of turning points only, with start and end
  set p-labels ["2" "3" "4" "6" "start" "end"]
  set t-labels ["t1" "t2" "t3" "t4" "t5" "t6" "t7" "t8" "t9" "t10" "t11" "t12" "t13" "t14" "t15" "t16" "t17" "t18" "t19"]
  ;;then plot
  foreach point-locations [
    ifelse member? item 0 ? p-labels
    [
      create-points 1 [
        set xcor item 1 ?1
        set ycor item 2 ?1
        set label item 0 ?1
        set label-color black
        
        ifelse item 0 ? = "start" or item 0 ? = "end"
        [
          set size 0.7
          set color yellow
          set shape "star"
        ]
        [
          set size 0.6
          set color red
          set shape "circle"
        ]
      ]
    ]
    [
      create-points 1 [
        set xcor item 1 ?1
        set ycor item 2 ?1
        set shape "square"
        set size 0.5
        set label item 0 ?1
        set label-color black
        set color green
      ]      
    ]
  ]
  

end

to draw-roads
  
  ask points with [label = "start"] [ create-road-to one-of points with [label = "2"] ]
  
  ;;capacity
  ask points with [label = "start"] [ ask out-link-to one-of points with [label = "2"] [set capacity 10] ]
  
  ;;route 1
  ask points with [label = "2"] [ create-road-to one-of points with [label = "t1"] ]
  ask points with [label = "t1"] [ create-road-to one-of points with [label = "t2"] ]
  ask points with [label = "t2"] [ create-road-to one-of points with [label = "t3"] ]
  ask points with [label = "t3"] [ create-road-to one-of points with [label = "end"] ]
  
  ;;set capacity for road
  ask points with [label = "2"] [ ask out-link-to one-of points with [label = "t1"] [set capacity 8] ]
  ask points with [label = "t1"] [ ask out-link-to one-of points with [label = "t2"] [set capacity 8] ]
  ask points with [label = "t2"] [ ask out-link-to one-of points with [label = "t3"] [set capacity 4] ]
  ask points with [label = "t3"] [ ask out-link-to one-of points with [label = "end"] [set capacity 3] ]

  ;;route 2 decision at point 2
  ask points with [label = "2"] [ create-road-to one-of points with [label = "3"] ]
  ask points with [label = "3"] [ create-road-to one-of points with [label = "t4"] ]
  ask points with [label = "t4"] [ create-road-to one-of points with [label = "4"] ]
  ask points with [label = "4"] [ create-road-to one-of points with [label = "t12"] ]
  ask points with [label = "t12"] [ create-road-to one-of points with [label = "t13"] ]
  ask points with [label = "t13"] [ create-road-to one-of points with [label = "t14"] ]
  ask points with [label = "t14"] [ create-road-to one-of points with [label = "t15"] ]
  ask points with [label = "t15"] [ create-road-to one-of points with [label = "t3"] ]
  ask points with [label = "t3"] [ create-road-to one-of points with [label = "end"] ]
  
  ask points with [label = "2"] [ ask out-link-to one-of points with [label = "3"] [set capacity 6] ]
  ask points with [label = "3"] [ ask out-link-to one-of points with [label = "t4"] [set capacity 4] ]
  ask points with [label = "t4"] [ ask out-link-to one-of points with [label = "4"] [set capacity 4] ]
  ask points with [label = "4"] [ ask out-link-to one-of points with [label = "t12"] [set capacity 2] ]
  ask points with [label = "t12"] [ ask out-link-to one-of points with [label = "t13"] [set capacity 4] ]
  ask points with [label = "t13"] [ ask out-link-to one-of points with [label = "t14"] [set capacity 3] ]
  ask points with [label = "t14"] [ ask out-link-to one-of points with [label = "t15"] [set capacity 2] ]
  ask points with [label = "t15"] [ ask out-link-to one-of points with [label = "t3"] [set capacity 4] ]    
  ask points with [label = "t3"] [ ask out-link-to one-of points with [label = "end"] [set capacity 3] ]   
  
  ;;route 3 decision at point 4
  ask points with [label = "4"] [ create-road-to one-of points with [label = "t18"] ]
  ask points with [label = "t18"] [ create-road-to one-of points with [label = "t5"] ]
  ask points with [label = "t5"] [ create-road-to one-of points with [label = "t9"] ]
  ask points with [label = "t9"] [ create-road-to one-of points with [label = "t6"] ]
  ask points with [label = "t6"] [ create-road-to one-of points with [label = "t10"] ]
  ask points with [label = "t10"] [ create-road-to one-of points with [label = "t11"] ]
  ask points with [label = "t11"] [ create-road-to one-of points with [label = "t16"] ]
  ask points with [label = "t16"] [ create-road-to one-of points with [label = "end"] ]

;;capcity
  ask points with [label = "4"] [ ask out-link-to one-of points with [label = "t18"] [set capacity 6] ]
  ask points with [label = "t18"] [ ask out-link-to one-of points with [label = "t5"] [set capacity 4] ]
  ask points with [label = "t5"] [ ask out-link-to one-of points with [label = "t9"] [set capacity 4] ]
  ask points with [label = "t9"] [ ask out-link-to one-of points with [label = "t6"] [set capacity 2] ]
  ask points with [label = "t6"] [ ask out-link-to one-of points with [label = "t10"] [set capacity 2] ]
  ask points with [label = "t10"] [ ask out-link-to one-of points with [label = "t11"] [set capacity 4] ]
  ask points with [label = "t11"] [ ask out-link-to one-of points with [label = "t16"] [set capacity 3] ]
  ask points with [label = "t16"] [ ask out-link-to one-of points with [label = "end"] [set capacity 2] ]  
    
  ;;route 4 decision at point 3
  ask points with [label = "3"] [ create-road-to one-of points with [label = "t19"] ]
  ask points with [label = "t19"] [ create-road-to one-of points with [label = "6"] ]
  ask points with [label = "6"] [ create-road-to one-of points with [label = "t7"] ]
  ask points with [label = "t7"] [ create-road-to one-of points with [label = "t8"] ]
  ask points with [label = "t8"] [ create-road-to one-of points with [label = "t9"] ]
  ask points with [label = "6"] [ create-road-to one-of points with [label = "t7"] ]
  ask points with [label = "t7"] [ create-road-to one-of points with [label = "t8"] ]
  
  
 ;;capacity
  ask points with [label = "3"] [ ask out-link-to one-of points with [label = "t19"] [set capacity 6] ]
  ask points with [label = "t19"] [ ask out-link-to one-of points with [label = "6"] [set capacity 4] ]
  ask points with [label = "6"] [ ask out-link-to one-of points with [label = "t7"] [set capacity 4] ]
  ask points with [label = "t7"] [ ask out-link-to one-of points with [label = "t8"] [set capacity 2] ]
  ask points with [label = "t8"] [ ask out-link-to one-of points with [label = "t9"] [set capacity 4] ]
  ask points with [label = "6"] [ ask out-link-to one-of points with [label = "t7"] [set capacity 3] ]
  ask points with [label = "t7"] [ ask out-link-to one-of points with [label = "t8"] [set capacity 2] ]
  
  ;;route 5 decision at point 6
  ask points with [label = "6"] [ create-road-to one-of points with [label = "t17"] ]
  ask points with [label = "t17"] [ create-road-to one-of points with [label = "t10"] ]

  ask points with [label = "6"] [ ask out-link-to one-of points with [label = "t17"] [set capacity 6] ]
  ask points with [label = "t17"] [ ask out-link-to one-of points with [label = "t10"] [set capacity 4] ]

  
  ;;set default road settings
  ask roads [
    set color black
    set v-count 0
    set thickness 0.3
    set has-erp? false
    
  ]
  
  ;;draw erp1 coloring for links if enabled
  if erp1
  [
    ask points with [label = "2"] [ ask out-link-to one-of points with [label = "t1"] [set color blue set has-erp? true] ]
    ask points with [label = "t1"] [ ask out-link-to one-of points with [label = "t2"] [set color blue set has-erp? true] ]
    ask points with [label = "t2"] [ ask out-link-to one-of points with [label = "t3"] [set color blue set has-erp? true] ]
    ask points with [label = "t3"] [ ask out-link-to one-of points with [label = "end"] [set color blue set has-erp? true] ]
  ]
  
  if erp2
  [
    ask points with [label = "2"] [ ask out-link-to one-of points with [label = "3"] [set color blue set has-erp? true] ]
  ]
  
  if erp3
  [
    ask points with [label = "3"] [ ask out-link-to one-of points with [label = "t4"] [set color blue set has-erp? true] ]
    ask points with [label = "t4"] [ ask out-link-to one-of points with [label = "4"] [set color blue set has-erp? true] ]  
  ]
  
  if erp4
  [
    ask points with [label = "3"] [ ask out-link-to one-of points with [label = "t19"] [set color blue set has-erp? true] ]
    ask points with [label = "t19"] [ ask out-link-to one-of points with [label = "6"] [set color blue set has-erp? true] ]    
  ]
  if erp5
  [
    ask points with [label = "4"] [ ask out-link-to one-of points with [label = "t12"] [set color blue set has-erp? true] ]
    ask points with [label = "t12"] [ ask out-link-to one-of points with [label = "t13"] [set color blue set has-erp? true] ]
    ask points with [label = "t13"] [ ask out-link-to one-of points with [label = "t14"] [set color blue set has-erp? true] ]
    ask points with [label = "t14"] [ ask out-link-to one-of points with [label = "t15"] [set color blue set has-erp? true] ]
    ask points with [label = "t15"] [ ask out-link-to one-of points with [label = "t3"] [set color blue set has-erp? true] ]
  ]
  
  
  ;;set path array for easier manipulation of calculating distances
  set paths
  [
    ["2" "3"]
    ["2" "t1" "t2" "t3" "t16" "end"]
    ["3" "t19" "6"]
    ["3" "t4" "4"]
    ["6" "t7" "t8" "t9" "t6" "t10" "t11" "t16" "end"]
    ["6" "t17" "t10" "t11" "t16" "end"]
    ["4" "t18" "t5" "t9" "t6" "t10" "t11" "t16" "end"]
    ["4" "t12" "t13" "t14" "t15" "t3" "t16" "end"]
  ]
  
  ;;pre calculate path distances for each in-between connectors (put the distance as the first item)
  let p-index 0
  foreach paths
  [
    let in-between-points ?
    let index 0
    let dist 0
    while [index < (length in-between-points - 1)]
    [
      ;;calc total distance
      ask one-of points with [label = item index in-between-points]
      [
        set dist (dist + distance one-of points with [label = item (index + 1) in-between-points])
      ]
      set index (index + 1)
    ]
    set ? fput dist ?
    set paths replace-item p-index paths ?
    set p-index (p-index + 1)
  ]
  
end
@#$#@#$#@
GRAPHICS-WINDOW
202
10
979
626
29
22
13.0
1
10
1
1
1
0
1
1
1
-29
29
-22
22
0
0
1
ticks
30.0

BUTTON
0
1
66
34
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
66
1
147
34
go once
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
148
1
211
34
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
-1
369
199
519
distance travelled by all cars
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot sum [distance-travelled] of vehicles"

SWITCH
105
265
208
298
erp1
erp1
1
1
-1000

SWITCH
2
240
105
273
erp2
erp2
1
1
-1000

SWITCH
3
275
106
308
erp3
erp3
1
1
-1000

SWITCH
1
308
104
341
erp4
erp4
1
1
-1000

SWITCH
1
341
104
374
erp5
erp5
1
1
-1000

SLIDER
0
37
172
70
num-vehicles
num-vehicles
0
200
138
1
1
NIL
HORIZONTAL

SLIDER
1
190
173
223
var-urgent
var-urgent
0
1
1
0.01
1
NIL
HORIZONTAL

SLIDER
1
156
173
189
var-thrift
var-thrift
0
1
1
0.01
1
NIL
HORIZONTAL

SLIDER
6
111
178
144
mid-urgent
mid-urgent
0
1
0.3
0.01
1
NIL
HORIZONTAL

SLIDER
5
77
177
110
mid-thrift
mid-thrift
0
1
0.41
0.01
1
NIL
HORIZONTAL

PLOT
2
519
202
669
plot 1
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot total-wait-count"

MONITOR
214
629
271
674
NIL
route1
17
1
11

MONITOR
274
630
331
675
NIL
route2
17
1
11

MONITOR
336
630
393
675
NIL
route3
17
1
11

MONITOR
394
630
451
675
NIL
route4
17
1
11

MONITOR
455
631
512
676
NIL
route5
17
1
11

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
0
Rectangle -7500403 true true 151 225 180 285
Rectangle -7500403 true true 47 225 75 285
Rectangle -7500403 true true 15 75 210 225
Circle -7500403 true true 135 75 150
Circle -16777216 true false 165 76 116

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.0RC6
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 1.0 0.0
0.0 1 1.0 0.0
0.2 0 1.0 0.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
0
@#$#@#$#@
