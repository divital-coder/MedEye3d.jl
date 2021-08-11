using DrWatson
@quickactivate "Probabilistic medical segmentation"


ReactOnMouseClickAndDragSTR="""
module 
code adapted from https://discourse.julialang.org/t/custom-subject-in-rocket-jl-for-mouse-events-from-glfw/65133/3
it is design to help processing data from 
    -GLFW.SetCursorPosCallback(window, (_, x, y) -> println("cursor: x, y")) and  for example : cursor: 29.0, 469.0  types   Float64  Float64   
    -GLFW.SetMouseButtonCallback(window, (_, button, action, mods) -> println("button action"))  for example types MOUSE_BUTTON_1 PRESS   GLFW.MouseButton  GLFW.Action 
The main function is to mark the interaction of the mouse to be saved in appropriate mask and be rendered onto the screen
so we modify the data that is the basis of the mouse interaction mask  and we pass the data on so appropriate part of the texture would be modified to be displayed on screen

"""
#@doc ReactOnMouseClickAndDragSTR
module ReactOnMouseClickAndDrag
using Rocket: isempty
using Rocket
using GLFW, ModernGL
using Main.ForDisplayStructs
using Main.TextureManag
using Main.OpenGLDisplayUtils
using  Dates
using  Parameters
export registerMouseClickFunctions
export reactToMouseDrag

MouseCallbackSubscribableStr="""
struct that enables reacting to  the input  from mouse click  and drag the input will be 
    Cartesian index represening (x,y)
     x and y position  of the mouse - will be recorded only if left mouse button is pressed or keep presssed
"""
@doc MouseCallbackSubscribableStr
mutable struct MouseCallbackSubscribable <: Subscribable{Vector{CartesianIndex{2}}}
    #true if left button is presed down - we make it true if the left button is pressed over image and false if mouse get out of the window or we get information about button release
    isLeftButtonDown ::Bool 
    #coordinates marking 4 corners of 
    #the quad that displays our medical image with the masks
    xmin::Int32
    ymin::Int32
    xmax::Int32
    ymax::Int32
#used to draw left button lines (creating lines)
 #store of the cartesian coordinates that is used to batch actions 
#- so if mouse is moving rapidly we would store bunch of coordinates and then modify texture in batch
    coordinatesStoreForLeftClicks ::Vector{CartesianIndex{2}} 
    lastCoordinate::CartesianIndex{2}#generally when we draw lines we remove points from array above yet w need to leave last one in order to keep continuity of futher line


referenceInstance::DateTime# an instance from which we would calculate when to execute batch 
    
    subject :: Subject{Vector{CartesianIndex{2}}} # coordinates of mouse 
   
end



```@doc
configuting Rocket on Subscribe so we get custom handler of input as we see we still need to define actor
```
# function Rocket.on_subscribe!(handler::MouseCallbackSubscribable, actor::SyncActor{Any, ActorWithOpenGlObjects})
#     return subscribe!(handler.subject, actor)
# end

function Rocket.on_subscribe!(handler::MouseCallbackSubscribable, actor::SyncActor{Any, ActorWithOpenGlObjects})

    return subscribe!(handler.subject, actor)
end


handlerStr="""
we define how handler should act on the subject - observable so it will pass event onto subject - here we have 2 events that we want to be ready for - mouse button press
example of possible inputs that we would be intrested in 
for example : cursor: 29.0, 469.0  types   Float64  Float64   
for example  MOUSE_BUTTON_1 PRESS    types GLFW.MouseButton  GLFW.Action 
             MOUSE_BUTTON_1 RELEASE  types GLFW.MouseButton  GLFW.Action 
We get two overloads so we will be able to respond with single handler to both mouse click and mouse position
Enum GLFW.Action:
RELEASE = 0
PRESS = 1
REPEAT = 2
Enum GLFW.MouseButton:
MOUSE_BUTTON_1 = 0
MOUSE_BUTTON_2 = 1

experiments show that max x,y in window is both 600 if window width and height is 600 
 so in order to specify weather we are over aour quad we need to know how big is primary quad -
  defaoul it is occupying 100% of y axis and first left 80% of x axis
  hence we can calculate max height to equal the height of the window 
"""
@doc handlerStr
function (handler::MouseCallbackSubscribable)( a, x::Float64, y::Float64)
  point = CartesianIndex(Int(x),Int(y))
  handler.lastCoordinate = point
  
  #  @info "handling mouse position start "   x
  
  if  (handler.isLeftButtonDown && x>=handler.xmin && x<=handler.xmax && y>=handler.ymin && y<= handler.ymax )
    push!(handler.coordinatesStoreForLeftClicks,point)
        if((Dates.now()-handler.referenceInstance).value>100)  
            #sending mouse position only if all conditions are met
            next!(handler.subject, handler.coordinatesStoreForLeftClicks)#sending mouse position only if all conditions are met
            handler.referenceInstance=Dates.now()
            handler.coordinatesStoreForLeftClicks = [point]
        end#if
   end#if

end #handler

@doc handlerStr
function (handler::MouseCallbackSubscribable)(a, button::GLFW.MouseButton, action::GLFW.Action,m)

    res=(button==GLFW.MOUSE_BUTTON_1 &&  action==GLFW.PRESS)#so it will stop either as we relese left mouse or click right
    handler.isLeftButtonDown = res
    if(res)
        handler.referenceInstance=Dates.now()
        handler.coordinatesStoreForLeftClicks = [handler.lastCoordinate]
    end #if
end #second handler



registerMouseClickFunctionsStr="""
we pass coordinate of cursor only when isLeftButtonDown is true and we make it true 
if left button is presed down - we make it true if the left button is pressed over image and false if mouse get out of the window or we get information about button release
imageWidth adn imageHeight are the dimensions of textures that we use to display 
"""
@doc registerMouseClickFunctionsStr
function registerMouseClickFunctions(window::GLFW.Window
                                    ,stopListening::Base.Threads.Atomic{Bool}
                                    )


 stopListening[]=true # stoping event listening loop to free the GLFW context

  # calculating dimensions of quad becouse it do not occupy whole window

 windowDims =     GLFW.GetWindowSize(window)

 width = windowDims[1]
  height = windowDims[2]
  quadmaxX = Int32(floor(width*0.8))
  quadMaxY = height 

  mouseButtonSubs = MouseCallbackSubscribable(false,0,0,quadmaxX,quadMaxY,[],CartesianIndex(1,1),Dates.now(),
  Subject(Vector{CartesianIndex{2}}, scheduler = AsyncScheduler()))


# GLFW.SetScrollCallback(window, (a, xoff, yoff) -> scrollback(a, xoff, yoff))
GLFW.SetCursorPosCallback(window, (a, x, y) -> mouseButtonSubs(a,x, y ) )# and  for example : cursor: 29.0, 469.0  types   Float64  Float64   
GLFW.SetMouseButtonCallback(window, (a, button, action, mods) ->mouseButtonSubs(a,button, action,mods )) # for example types MOUSE_BUTTON_1 PRESS   GLFW.MouseButton  GLFW.Action 

stopListening[]=false # reactivate event listening loop

#subscription = subscribe!(buttonSubs, (direction) -> println(direction)) -usefull for debugging

return mouseButtonSubs



end #registerMouseScrollFunctions


reactToMouseDragStr = """
we use mouse coordinate to modify the texture that is currently active for modifications 
    - we take information about texture currently active for modifications from variables stored in actor
    from texture specification we take also its id and its properties ...
"""
@doc reactToMouseDragStr
function reactToMouseDrag(mouseCoords::Vector{CartesianIndex{2}}, actor::SyncActor{Any, ActorWithOpenGlObjects})
    obj = actor.actor.mainForDisplayObjects
    obj.stopListening[]=true #free GLFW context
    textureList = actor.actor.textureToModifyVec

    if (!isempty(textureList))
        texture= textureList[1]
        
       mappedCoords =  translateMouseToTexture(texture.strokeWidth
                                                ,mouseCoords
                                                ,obj.windowWidth
                                                , obj.windowHeight
                                                , obj.imageTextureWidth
                                                , obj.imageTextureHeight
                                                ,actor.actor.currentDisplayedSlice)

        for datTupl in  actor.actor.onScrollData
            if(datTupl[1]==texture.name)
                @info "texture to update " texture.name 
                datTupl[2][mappedCoords].=1 # broadcasting new value to all points that we are intrested in     
                updateTexture(datTupl[2][actor.actor.currentDisplayedSlice,:,:], texture)
                break
            end#if
        end #for


        # updateTexture(ones(strokeWidth,strokeWidth),  texture   ,
        # Int64(floor( ((mouseCoord[1])/(obj.windowWidth*0.9))*obj.imageTextureWidth)  )- halfStroke # subtracting it to make middle of stroke in pixel we are with mouse on 
        # ,Int64(floor(  ((obj.windowHeight-mouseCoord[2])/obj.windowHeight)*obj.imageTextureHeight)  ) -halfStroke
        # ,strokeWidth,strokeWidth )
 
        # updateTexture(ones(strokeWidth,strokeWidth),texture,
        # calcX -halfStroke      # subtracting it to make middle of stroke in pixel we are with mouse on 
        # ,calcY- halfStroke,strokeWidth,strokeWidth )
    

    
for text in obj.listOfTextSpecifications
        glBindTexture(GL_TEXTURE_2D, text.ID[]); 
end #for        
        basicRender(obj.window)

#updating data
       
    end #if 
    obj.stopListening[]=false # reactivete event listening loop

    #send data for persistent storage TODO() modify for scrolling data 
end#reactToScroll


```@doc
given list of cartesian coordinates and some window/ image characteristics - it translates mouse positions
to cartesian coordinates of the texture
strokeWidth - the property connected to the texture marking how thick should be the brush
mouseCoords - list of coordinates of mouse positions while left button remains pressed
windowWidth,windowHeight  - dimensions of the GLFW window
imageTextureWidth, imageTextureHeight - dimension of the texture holding image
currentDisplayedSlice - the slice we are on now
return vector of translated cartesian coordinates
```
function translateMouseToTexture(strokeWidth::Int32
                                ,mouseCoords::Vector{CartesianIndex{2}}
                                ,windowWidth::Int32
                                ,windowHeight::Int32 
                                ,imageTextureWidth::Int32 
                                ,imageTextureHeight::Int32 
                                ,currentDisplayedSlice::Int64  )
  
    halfStroke =   Int64(floor(strokeWidth/2 ))
    #updating given texture that we are intrested in in place we are intested in 

    return map(c->CartesianIndex(currentDisplayedSlice ,Int64(floor( ((c[1])/(windowWidth*0.9))*imageTextureWidth))
    , Int64(floor(  ((windowHeight-c[2])/windowHeight)*imageTextureHeight)  )     ),mouseCoords)                                                    |>
      (x)->filter(it->it[1]>0 && it[2]>0 && it[3]>0 ,x)        # we do not want to try access it in point 0 as julia is 1 indexed                 

    # calcX = Int64(floor( ((mouseCoord[1])/(windowWidth*0.9))*imageTextureWidth)  )
    # calcY = Int64(floor(  ((windowHeight-mouseCoord[2])/windowHeight)*imageTextureHeight)  )       
 
end #translateMouseToTexture



end #ReactOnMouseClickAndDrag