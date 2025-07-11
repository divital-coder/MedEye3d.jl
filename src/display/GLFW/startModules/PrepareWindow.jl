module PrepareWindow

using Base.Threads, ModernGL, GeometryTypes, GLFW, Logging
using ..PrepareWindowHelpers, ..OpenGLDisplayUtils, ..DataStructs, ..ShadersAndVerticies, ..ForDisplayStructs, ..ShadersAndVerticiesForText, ..ModernGlUtil

export displayAll, createAndInitShaderProgram


"""
preparing all for displaying the images and responding to mouse and keyboard input
	listOfTexturesToCreate- list of texture specifications needed to for example create optimal shader
	calcDimsStruct - holds important data about verticies, textures dimensions etc.
"""
function displayAll(calcDimsStruct::CalcDimsStruct)

    if (nthreads(:interactive) == 0)
        @error " MedEye3D above version 0.5.6 requires setting of the interactive Thread (feature available from Julia 1.9 ) one can set it in linux by enviromental variable export JULIA_NUM_THREADS=3,1 where 1 after the coma is the interactive thread and 3 is the number of the other threads available on your machine; or start julia like this julia --threads 3,1; you can also use the docker container prepared by the author from  https://github.com/jakubMitura14/MedPipe3DTutorial. . More about interactive THreads on https://docs.julialang.org/en/v1/manual/multi-threading/"
        throw(error())

    end #if


    if (Threads.nthreads() == 1)
        @warn "increase number of available threads look into https://docs.julialang.org/en/v1/manual/multi-threading/  or modify for example in vs code extension"
    end
    # Create the window. This sets all the hints and makes the context current.


    window = initializeWindow(calcDimsStruct.windowWidth, calcDimsStruct.windowHeight)

    # The shaders
    createcontextinfo()
    gslsStr = get_glsl_version_string()


    vertex_shader = createVertexShader(gslsStr)

    # masks = filter(textSpec -> !textSpec.isMainImage, listOfTexturesToCreate)
    # someExampleMask = masks[begin]
    # someExampleMaskB = masks[end]
    # @info "masks set for subtraction $(someExampleMask.name)" someExampleMaskB.name
    # fragment_shader_main, shader_program = createAndInitShaderProgram(vertex_shader, listOfTexturesToCreate, someExampleMask, someExampleMaskB, gslsStr)
    # fragment_shader_main, shader_program = createAndInitShaderProgram(vertex_shader, listOfTexturesToCreate, gslsStr)


    ##for control of text display
    fragment_shader_words = ShadersAndVerticiesForText.createFragmentShader(gslsStr)
    shader_program_words = glCreateProgram()
    glAttachShader(shader_program_words, fragment_shader_words)
    glAttachShader(shader_program_words, vertex_shader)


    vbo_words = Ref(GLuint(1))   # initial value is irrelevant, just allocate space
    glGenBuffers(1, vbo_words)
    ##for control of text display


    ###########buffers
    #create vertex buffer
    vao = createVertexBuffer()
    # Create the Vertex Buffer Objects (VBO)
    # vbo = createDAtaBuffer(calcDimsStruct.mainImageQuadVert)

    # Create the Element Buffer Object (EBO)
    ebo = createElementBuffer(ShadersAndVerticies.elements)
    ############ how data should be read from data buffer
    encodeDataFromDataBuffer()
    #capturing The data from GLFW
    controllWindowInput(window)

    #loop that enables reacting to mouse and keyboards inputs  so every 0.1 seconds it will check GLFW weather any new events happened
    pollingTask, stopChannel = createPollingTask(window)
    schedule(pollingTask)

    return (window, vertex_shader, vao, ebo, fragment_shader_words, vbo_words, shader_program_words, gslsStr, stopChannel)

end# displayAll


"""
On the basis of information from listOfTexturesToCreate it creates specialized shader program
"""
function createAndInitShaderProgram(vertex_shader::UInt32, listOfTexturesToCreate::Vector{TextureSpec{Float32}}, gslsStr::String, calcDimsStruct::CalcDimsStruct, num)

    fragment_shader = nothing
    if num == 1
        fragment_shader = ShadersAndVerticies.createFragmentShader(gslsStr, listOfTexturesToCreate, "green")
    else
        fragment_shader = ShadersAndVerticies.createFragmentShader(gslsStr, listOfTexturesToCreate, "red")

    end

    shader_program = glCreateProgram()
    glAttachShader(shader_program, fragment_shader)
    glAttachShader(shader_program, vertex_shader)
    glLinkProgram(shader_program)
    vbo = createDAtaBuffer(calcDimsStruct.mainImageQuadVert)
    glUseProgram(shader_program)

    return (fragment_shader, shader_program, vbo)

end#createShaderProgram


"""
Polling task creation
"""
function createPollingTask(window::GLFW.Window)
    stopChannel = Channel{Bool}(1)
    
    t = @task begin
        try
            while true
                # Check for stop signal first
                if isready(stopChannel)
                    take!(stopChannel)
                    break
                end
                
                # Check if window should close
                if GLFW.WindowShouldClose(window)
                    break
                end
                
                sleep(0.001)
                
                # Final check before polling
                if !isready(stopChannel) && !GLFW.WindowShouldClose(window)
                    GLFW.PollEvents()
                end
            end
        catch e
            @debug "GLFW polling task terminated: $e"
        finally
            @debug "GLFW polling task ended"
        end
    end
    
    return (t, stopChannel)
end



end #PreperWindow
