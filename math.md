


damit cude geht: alles ist eine matrix (oder array).


für zeitschrit t und individum i

sensor_i_t * weight_i_in = hidden_i_t

hidden_i_t * weight_i_hidden = hidden_i_t

hidden_i_t * weight_i_out = act_i_t

act_i_t ist die ausgabe eines individuums
 
act_t ist die ausgaber aller individuuen. 


proximity_grid # low-resolution 2d array where each cell is a linked_list
proximity_stack # 

function perform!(state_i_t, act_i_t)
    update_rotation!
    update_position!
    update_energy

end

function update_position!(playing_field,rotation, movement, old_position)
    target_x = old_position_x + sin(rotation)*movement
    target_y = old_position_y + cos(rotation)*movement
    update_proximity!(proximity_grid, proximity_stack, target)
end

function update_proximity!(proximity_grid, proximity_stack, target)
    append to target_cell
    if target_cell > 1: add to proximity_stack
end


nachdem alle position geupdated wurden, wird der proximity_stack abgearbeitet; 

foreach cell in proximity_stack:
    
end


state_i_t ist der state eines individuums



