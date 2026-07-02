local colors = {
    wallpaper = "{{wallpaper}}",
    background = "{{background}}",
    foreground = "{{foreground}}",
    cursor = "{{cursor}}",
    color0 = "{{color0}}",
    color1 = "{{color1}}",
    color2 = "{{color2}}",
    color3 = "{{color3}}",
    color4 = "{{color4}}",
    color5 = "{{color5}}",
    color6 = "{{color6}}",
    color7 = "{{color7}}",
    color8 = "{{color8}}",
    color9 = "{{color9}}",
    color10 = "{{color10}}",
    color11 = "{{color11}}",
    color12 = "{{color12}}",
    color13 = "{{color13}}",
    color14 = "{{color14}}",
    color15 = "{{color15}}",
    
    -- Specific Hyprland formatting
    active_border = {
        colors = { "rgb({{color3 | strip}})", "rgb({{color4 | strip}})", "rgb({{color5 | strip}})", "rgb({{color6 | strip}})", "rgb({{color2 | strip}})" },
        angle = 45
    },
    inactive_border = "rgba({{background | strip}}ee)"
}

return colors
