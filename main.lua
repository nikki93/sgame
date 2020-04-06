local sqlite3 = require 'lsqlite3'
local db = sqlite3.open_memory()


local function check(...)
    local code = db:errcode()
    if code ~= 0 then
        error('db error ' .. code .. ': ' .. db:errmsg(), 3)
    end
    return ...
end

local function prepare(...)
    return check(db:prepare(...))
end

local function run(s, ...)
    if select('#', ...) > 0 then
        if type(select(1, ...)) == 'table' then
            s:bind_names(...)
        else
            s:bind_values(...)
        end
    end
    while s:step() == sqlite3.ROW do
    end
    s:reset()
end

local function exec(sql, ...)
    if select('#', ...) > 0 then
        local s = check(db:prepare(sql))
        run(s, ...)
    else
        check(db:exec(sql))
    end
end


exec([[
    pragma foreign_keys;

    create table object (
        id integer primary key,
        name
    );

    create table position (
        id, x, y,

        foreign key (id) references object(id)
    );

    create table circle (
        id, radius,

        foreign key (id) references object(id)
    );
]])


function love.load()
    local W, H = love.graphics.getDimensions()
    for i = 1, 20 do
        exec([[
            insert into object (name) values ("test");
        ]])
        local id = db:last_insert_rowid()
        exec([[
            insert into position (id, x, y) values (?, ?, ?);
        ]], id, W * math.random(), H * math.random())
        exec([[
            insert into circle (id, radius) values (?, 20);
        ]], id)
    end
end


local drawCircleS = prepare([[
    select position.x, position.y, circle.radius
        from position, circle
        where position.id = circle.id;
]])
function love.draw()
    for x, y, radius in drawCircleS:urows() do
        love.graphics.circle('fill', x, y, radius)
    end
    drawCircleS:reset()
end


local updateS = prepare([[
    update position
        set y = y + 100 * $dt;
]])
function love.update(dt)
    run(updateS, { dt = dt })
end


local ui = castle.ui

function castle.uiupdate()
    do return end
end
