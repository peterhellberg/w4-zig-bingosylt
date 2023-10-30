{{#sprites}}
pub const {{name}} = Sprite{
    .sprite = ([{{length}}]u8{ {{bytes}} })[0..],
    .width = {{width}},
    .height = {{height}},
    .flags = {{flags}}, // {{flagsHumanReadable}}
};
{{/sprites}}
