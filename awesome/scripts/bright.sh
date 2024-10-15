percent=$(brightnessctl | grep -Po '[0-9]{1,3}(?=%)' | head -n 1)
echo $percent
