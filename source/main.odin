package main

import "core:fmt"
import rand "core:math/rand"
import glm "core:math/linalg/glsl"
import sdl "vendor:sdl2"
import gl "vendor:OpenGL"

WINDOW_TITLE :: "Odin SDL2 Template"
WINDOW_WIDTH :: 960
WINDOW_HEIGHT :: 540
GL_VERSION_MAJOR :: 4
GL_VERSION_MINOR :: 6

POINT_CAP :: 1024
POINT_POS_MIN : f32 : -256
POINT_POS_MAX : f32 : 256
POINT_RADIUS_MIN : f32 : 0.5
POINT_RADIUS_MAX : f32 : 8

VERTEX_SOURCE :: `#version 460 core
    layout(location = 0) in vec3 i_position;
    layout(location = 1) in float i_radius;
    layout(location = 2) in int i_color;
    flat out float v_radius;
    flat out int v_color;
    out vec2 v_tex_coord;
    uniform mat4 u_projection;
    uniform mat4 u_view;

    const vec2 positions[4] = vec2[](
        vec2(-1.0, -1.0),
        vec2(1.0, -1.0),
        vec2(-1.0, 1.0),
        vec2(1.0, 1.0)
    );

    const vec2 tex_coords[4] = vec2[](
        vec2(0.0, 0.0),
        vec2(1.0, 0.0),
        vec2(0.0, 1.0),
        vec2(1.0, 1.0)
    );

    void main() {
        mat3 cam_rot = transpose(mat3(u_view));
        vec3 local = cam_rot * vec3(positions[gl_VertexID] * i_radius, 0.0);
        vec3 position = local + i_position;

        gl_Position = u_projection * u_view * vec4(position, 1.0);
        v_radius = i_radius;
        v_color = i_color;
        v_tex_coord = tex_coords[gl_VertexID];
    }
`

FRAGMENT_SOURCE :: `#version 460 core
    precision mediump float;
    flat in int v_color;
    in vec2 v_tex_coord;
    out vec4 o_frag_color;

    vec3 get_color(int color) {
        return vec3(
            (color >> 16) & 0xFF,
            (color >> 8) & 0xFF,
            color & 0xFF
        ) / 255.0;
    }

    void main() {
        vec2 uv = v_tex_coord;
        vec2 cp = uv * 2.0 - 1.0;

        if (cp.x * cp.x + cp.y * cp.y > 1.0) {
            discard;
        }

        o_frag_color = vec4(get_color(v_color), 1.0);
    }
`

Point :: struct {
    position: glm.vec3,
    radius: f32,
    color: i32
}

pack_color :: proc(color: glm.ivec3) -> i32 {
    return (color.x << 16) | (color.y << 8) | color.z;
}

random_color :: proc() -> i32 {
    return pack_color({rand.int31() % 256, rand.int31() % 256, rand.int31() % 256})
}

main :: proc() {
    if sdl.Init({.VIDEO}) < 0 {
        fmt.printf("SDL ERROR: %s\n", sdl.GetError())

        return
    }

    defer sdl.Quit()

     window := sdl.CreateWindow(WINDOW_TITLE, sdl.WINDOWPOS_CENTERED, sdl.WINDOWPOS_CENTERED, WINDOW_WIDTH, WINDOW_HEIGHT, {.OPENGL, .RESIZABLE})
    defer sdl.DestroyWindow(window)

    sdl.GL_SetAttribute(.CONTEXT_PROFILE_MASK, i32(sdl.GLprofile.CORE))
    sdl.GL_SetAttribute(.CONTEXT_MAJOR_VERSION, GL_VERSION_MAJOR)
    sdl.GL_SetAttribute(.CONTEXT_MINOR_VERSION, GL_VERSION_MINOR)

    gl_context := sdl.GL_CreateContext(window)
    defer sdl.GL_DeleteContext(gl_context)

    gl.load_up_to(GL_VERSION_MAJOR, GL_VERSION_MINOR, sdl.gl_set_proc_address)

    sdl.SetRelativeMouseMode(true)

    viewport_x, viewport_y: i32; sdl.GetWindowSize(window, &viewport_x, &viewport_y)
    key_state := sdl.GetKeyboardState(nil)
    time: u32 = sdl.GetTicks()
    time_delta : f32 = 0
    time_last := time

    camera: Camera; camera_new(&camera)
    movement_speed: f32 = 30
    yaw_speed: f32 = 0.002
    pitch_speed: f32 = 0.002

    program, program_status := gl.load_shaders_source(VERTEX_SOURCE, FRAGMENT_SOURCE)
    uniforms := gl.get_uniforms_from_program(program)

    if !program_status {
        fmt.printf("SHADER LOAD ERROR: %s\n", gl.get_last_error_message())

        return
    }

    defer gl.DeleteProgram(program)

    points : [POINT_CAP]Point

    for &point in points {
        point.position = {rand.float32_range(POINT_POS_MIN, POINT_POS_MAX), rand.float32_range(POINT_POS_MIN, POINT_POS_MAX), rand.float32_range(POINT_POS_MIN, POINT_POS_MAX)}
        point.radius = rand.float32_range(POINT_RADIUS_MIN, POINT_RADIUS_MAX)
        point.color = random_color()
    }

    vao: u32; gl.GenVertexArrays(1, &vao); defer gl.DeleteVertexArrays(1, &vao)
    gl.BindVertexArray(vao)

    vbo: u32; gl.GenBuffers(1, &vbo); defer gl.DeleteBuffers(1, &vbo)
    gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
    gl.BufferData(gl.ARRAY_BUFFER, POINT_CAP * size_of(Point), &points, gl.STATIC_DRAW)

    offset: i32 = 0
    gl.EnableVertexAttribArray(0)
    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, size_of(Point), auto_cast offset)
    gl.VertexAttribDivisor(0, 1)

    offset += size_of(glm.vec3)
    gl.EnableVertexAttribArray(1)
    gl.VertexAttribPointer(1, 1, gl.FLOAT, gl.FALSE, size_of(Point), auto_cast offset)
    gl.VertexAttribDivisor(1, 1)

    offset += size_of(i32)
    gl.EnableVertexAttribArray(2)
    gl.VertexAttribIPointer(2, 1, gl.INT, size_of(Point), auto_cast offset)
    gl.VertexAttribDivisor(2, 1)

    gl.Enable(gl.DEPTH_TEST)

    loop: for {
        time = sdl.GetTicks()
        time_delta = f32(time - time_last) / 1000
        time_last = time

        event: sdl.Event

        for sdl.PollEvent(&event) {
            #partial switch event.type {
                case .QUIT:
                    break loop
                case .WINDOWEVENT:
                    sdl.GetWindowSize(window, &viewport_x, &viewport_y)
                case .KEYDOWN:
                    if event.key.keysym.scancode == sdl.SCANCODE_ESCAPE {
                        sdl.SetRelativeMouseMode(!sdl.GetRelativeMouseMode())
                    }
                case .MOUSEMOTION:
                    if sdl.GetRelativeMouseMode() {
                        camera_rotate(&camera, auto_cast event.motion.xrel * yaw_speed, auto_cast event.motion.yrel * pitch_speed, 0)
                    }
            }
        }

        if (sdl.GetRelativeMouseMode()) {
            speed := time_delta * movement_speed

            if key_state[sdl.SCANCODE_A] == sdl.PRESSED {
                camera_move(&camera, {-speed, 0, 0})
            }

            if key_state[sdl.SCANCODE_D] == sdl.PRESSED {
                camera_move(&camera, {speed, 0, 0})
            }

            if key_state[sdl.SCANCODE_S] == sdl.PRESSED {
                camera_move(&camera, {0, 0, -speed})
            }

            if key_state[sdl.SCANCODE_W] == sdl.PRESSED {
                camera_move(&camera, {0, 0, speed})
            }
        }

        camera_compute_projection(&camera, auto_cast viewport_x, auto_cast viewport_y)
        camera_compute_view(&camera)

        gl.Viewport(0, 0, viewport_x, viewport_y)
        gl.ClearColor(0.75, 0.89, 0.95, 1.0)
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
        gl.Clear(gl.COLOR_BUFFER_BIT)
        gl.UseProgram(program)
        gl.UniformMatrix4fv(uniforms["u_projection"].location, 1, false, &camera.projection[0][0])
        gl.UniformMatrix4fv(uniforms["u_view"].location, 1, false, &camera.view[0][0])
        gl.DrawArraysInstanced(gl.TRIANGLE_STRIP, 0, 4, POINT_CAP)

        sdl.GL_SwapWindow(window)
    }
}
