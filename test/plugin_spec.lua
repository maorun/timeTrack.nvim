local maorunTime = require('maorun.time')
local os = require('os')

TestMaorunTime = {}

local tempPath = os.tmpname()

function TestMaorunTime:setUp()
    maorunTime.setup(tempPath)
end

function TestMaorunTime:testTimeStart()
    maorunTime.TimeStart()
    assert.is_false(maorunTime.isPaused())
end

function TestMaorunTime:testTimeStop()
    maorunTime.TimeStop()
    assert.is_true(maorunTime.isPaused())
end

function TestMaorunTime:testTimePause()
    maorunTime.TimePause()
    assert.is_true(maorunTime.isPaused())
end

function TestMaorunTime:testTimeResume()
    maorunTime.TimeResume()
    assert.is_false(maorunTime.isPaused())
end

