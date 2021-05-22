local Types = require('orgmode.parser.types')
local parser = require('orgmode.parser')
local Range = require('orgmode.parser.range')
local Date = require('orgmode.objects.date')

describe('Parser', function()
  it('should parse filetags headline', function()
    local lines = {
      '#+FILETAGS: Tag1, Tag2',
      '* TODO Something with a lot of tags :WORK:'
    }

    local parsed = parser.parse(lines, 'todos')
    assert.are.same(parsed.tags, {'Tag1', 'Tag2'})
    assert.are.same(parsed.items[2], {
      content = {},
      dates = {},
      headlines = {},
      level = 1,
      line = "* TODO Something with a lot of tags :WORK:",
      id = 2,
      range = Range.from_line(2),
      parent = 0,
      type = "HEADLINE",
      title = 'Something with a lot of tags',
      priority = '',
      todo_keyword = {
        value = 'TODO',
        range = Range:new({
          start_line = 2,
          end_line = 2,
          start_col = 3,
          end_col = 6
        }),
      },
      tags = {'WORK'},
      category = 'todos',
      file = '',
    })
  end)

  it('should parse lines', function()
    local lines = {
      'Top level content',
      '* TODO Test orgmode',
      '** TODO [#A] Test orgmode level 2 :PRIVATE:',
      'Some content for level 2',
      '*** NEXT [#1] Level 3',
      'Content Level 3',
      '* DONE top level todo :WORK:',
      'content for top level todo',
      '* TODO top level todo with multiple tags :OFFICE:PROJECT:',
      'multiple tags content, tags not read from content :FROMCONTENT:',
      '** NEXT Working on this now :OFFICE:NESTED:',
      '* NOKEYWORD Headline with wrong todo keyword and wrong tag format :WORK : OFFICE:',
    }

    local parsed = parser.parse(lines, 'todos')
    assert.are.same({
      level = 0,
      line = "Top level content",
      range = Range.from_line(1),
      id = 1,
      parent = 0,
      dates = {},
      type = "CONTENT",
    }, parsed.items[1])
    assert.are.same({
      content = {},
      dates = {},
      headlines = { 3 },
      level = 1,
      line = "* TODO Test orgmode",
      range = Range:new({ start_line = 2, end_line = 6 }),
      id = 2,
      parent = 0,
      priority = '',
      title = 'Test orgmode',
      type = "HEADLINE",
      category = 'todos',
      file = '',
      todo_keyword = {
        value = 'TODO',
        range = Range:new({
          start_line = 2,
          end_line = 2,
          start_col = 3,
          end_col = 6
        }),
      },
      tags = {},
    }, parsed.items[2])
    assert.are.same({
      content = { 4 },
      dates = {},
      headlines = { 5 },
      level = 2,
      line = "** TODO [#A] Test orgmode level 2 :PRIVATE:",
      range = Range:new({ start_line = 3, end_line = 6 }),
      id = 3,
      parent = 2,
      priority = 'A',
      title = 'Test orgmode level 2',
      type = "HEADLINE",
      category = 'todos',
      file = '',
      todo_keyword = {
        value = 'TODO',
        range = Range:new({
          start_line = 3,
          end_line = 3,
          start_col = 4,
          end_col = 7
        }),
      },
      tags = {'PRIVATE'},
    }, parsed.items[3])
    assert.are.same({
      level = 2,
      line = "Some content for level 2",
      id = 4,
      range = Range.from_line(4),
      dates = {},
      parent = 3,
      type = "CONTENT",
    }, parsed.items[4])
    assert.are.same({
      content = { 6 },
      dates = {},
      headlines = {},
      level = 3,
      line = "*** NEXT [#1] Level 3",
      id = 5,
      range = Range:new({ start_line = 5, end_line = 6 }),
      parent = 3,
      priority = '1',
      title = 'Level 3',
      type = "HEADLINE",
      category = 'todos',
      file = '',
      todo_keyword = {
        value = 'NEXT',
        range = Range:new({
          start_line = 5,
          end_line = 5,
          start_col = 5,
          end_col = 8
        }),
      },
      tags = {},
    }, parsed.items[5])
    assert.are.same({
      level = 3,
      line = "Content Level 3",
      id = 6,
      range = Range.from_line(6),
      dates = {},
      parent = 5,
      type = "CONTENT",
    }, parsed.items[6])
    assert.are.same({
      content = { 8 },
      dates = {},
      headlines = {},
      level = 1,
      line = "* DONE top level todo :WORK:",
      id = 7,
      priority = '',
      range = Range:new({ start_line = 7, end_line = 8 }),
      title = 'top level todo',
      parent = 0,
      type = "HEADLINE",
      category = 'todos',
      file = '',
      todo_keyword = {
        value = 'DONE',
        range = Range:new({
          start_line = 7,
          end_line = 7,
          start_col = 3,
          end_col = 6
        }),
      },
      tags = {'WORK'},
    }, parsed.items[7])
    assert.are.same({
      level = 1,
      line = "content for top level todo",
      id = 8,
      range = Range.from_line(8),
      parent = 7,
      dates = {},
      type = "CONTENT",
    }, parsed.items[8])
    assert.are.same({
      content = { 10 },
      dates = {},
      headlines = { 11 },
      level = 1,
      line = "* TODO top level todo with multiple tags :OFFICE:PROJECT:",
      id = 9,
      range = Range:new({ start_line = 9, end_line = 11 }),
      parent = 0,
      priority = '',
      title = 'top level todo with multiple tags',
      type = "HEADLINE",
      category = 'todos',
      file = '',
      todo_keyword = {
        value = 'TODO',
        range = Range:new({
          start_line = 9,
          end_line = 9,
          start_col = 3,
          end_col = 6
        }),
      },
      tags = {'OFFICE', 'PROJECT'},
    }, parsed.items[9])
    assert.are.same({
      level = 1,
      line = "multiple tags content, tags not read from content :FROMCONTENT:",
      id = 10,
      range = Range.from_line(10),
      dates = {},
      parent = 9,
      type = "CONTENT",
    }, parsed.items[10])
    assert.are.same({
      content = {},
      dates = {},
      headlines = {},
      level = 2,
      line = "** NEXT Working on this now :OFFICE:NESTED:",
      id = 11,
      range = Range.from_line(11),
      parent = 9,
      type = "HEADLINE",
      category = 'todos',
      file = '',
      priority = '',
      title = 'Working on this now',
      todo_keyword = {
        value = 'NEXT',
        range = Range:new({
          start_line = 11,
          end_line = 11,
          start_col = 4,
          end_col = 7
        }),
      },
      tags = {'OFFICE', 'NESTED'},
    }, parsed.items[11])
    assert.are.same({
      content = {},
      dates = {},
      headlines = {},
      level = 1,
      line = "* NOKEYWORD Headline with wrong todo keyword and wrong tag format :WORK : OFFICE:",
      id = 12,
      range = Range.from_line(12),
      parent = 0,
      priority = '',
      title = 'NOKEYWORD Headline with wrong todo keyword and wrong tag format :WORK : OFFICE:',
      type = "HEADLINE",
      category = 'todos',
      file = '',
      todo_keyword = { value = '' },
      tags = {},
    }, parsed.items[12])
    assert.are.same(0, parsed.level)
    assert.are.same(0, parsed.id)
    assert.are.same(lines, parsed.lines)
    assert.are.same(Range:new({
      start_line = 1,
      end_line = 12
    }), parsed.range)
  end)

  it('should parse headline and its planning dates', function()
    local lines = {
      '* TODO Test orgmode <2021-05-15 Sat> :WORK:',
      'DEADLINE: <2021-05-20 Thu> SCHEDULED: <2021-05-18> CLOSED: <2021-05-21 Fri>',
      '* TODO get deadline only if first line after headline',
      'Some content',
      'DEADLINE: <2021-05-22 Sat>'
    }

    local parsed = parser.parse(lines, 'work')
    assert.are.same({
      content = { 2 },
      dates = {
        Date.from_string('2021-05-15 Sat', {
          active = true,
          range = Range:new({
            start_line = 1,
            end_line = 1,
            start_col = 21,
            end_col = 36
          }),
        }),
        Date.from_string('2021-05-20 Thu', {
          type = 'DEADLINE',
          active = true,
          range = Range:new({
            start_line = 2,
            end_line = 2,
            start_col = 11,
            end_col = 26
          }),
        }),
        Date.from_string('2021-05-18', {
          type = 'SCHEDULED',
          active = true,
          range = Range:new({
            start_line = 2,
            end_line = 2,
            start_col = 39,
            end_col = 50
          }),
        }),
        Date.from_string('2021-05-21 Fri', {
          type = 'CLOSED',
          active = true,
          range = Range:new({
            start_line = 2,
            end_line = 2,
            start_col = 60,
            end_col = 75
          }),
        }),
      },
      headlines = {},
      level = 1,
      line = "* TODO Test orgmode <2021-05-15 Sat> :WORK:",
      id = 1,
      range = Range:new({
        start_line = 1,
        end_line = 2,
      }),
      parent = 0,
      priority = '',
      title = 'Test orgmode <2021-05-15 Sat>',
      type = "HEADLINE",
      category = 'work',
      file = '',
      todo_keyword = {
        value = 'TODO',
        range = Range:new({
          start_line = 1,
          end_line = 1,
          start_col = 3,
          end_col = 6
        }),
      },
      tags = {'WORK'},
    }, parsed.items[1])
    assert.are.same({
      level = 1,
      line = "DEADLINE: <2021-05-20 Thu> SCHEDULED: <2021-05-18> CLOSED: <2021-05-21 Fri>",
      id = 2,
      range = Range:new({
        start_line = 2,
        end_line = 2,
      }),
      parent = 1,
      type = "PLANNING",
      dates = {
        Date.from_string('2021-05-20 Thu', {
          type = 'DEADLINE',
          active = true,
          range = Range:new({
            start_line = 2,
            end_line = 2,
            start_col = 11,
            end_col = 26
          }),
        }),
        Date.from_string('2021-05-18', {
          type = 'SCHEDULED',
          active = true,
          range = Range:new({
            start_line = 2,
            end_line = 2,
            start_col = 39,
            end_col = 50
          }),
        }),
        Date.from_string('2021-05-21 Fri', {
          type = 'CLOSED',
          active = true,
          range = Range:new({
            start_line = 2,
            end_line = 2,
            start_col = 60,
            end_col = 75
          }),
        }),
      },
    }, parsed.items[2])
    assert.are.same({
      content = { 4, 5 },
      dates = {
        Date.from_string('2021-05-22 Sat', {
          active = true,
          type = 'NONE',
          range = Range:new({
            start_line = 5,
            end_line = 5,
            start_col = 11,
            end_col = 26
          }),
        }),
      },
      headlines = {},
      level = 1,
      line = "* TODO get deadline only if first line after headline",
      id = 3,
      range = Range:new({
        start_line = 3,
        end_line = 4,
      }),
      parent = 0,
      priority = '',
      title = 'get deadline only if first line after headline',
      type = "HEADLINE",
      category = 'work',
      file = '',
      todo_keyword = {
        value = 'TODO',
        range = Range:new({
          start_line = 3,
          end_line = 3,
          start_col = 3,
          end_col = 6
        }),
      },
      tags = {},
    }, parsed.items[3])
    assert.are.same({
      level = 1,
      line = "Some content",
      range = Range:new({
        start_line = 4,
        end_line = 4,
      }),
      id = 4,
      dates = {},
      parent = 3,
      type = "CONTENT",
    }, parsed.items[4])
    assert.are.same({
      level = 1,
      line = "DEADLINE: <2021-05-22 Sat>",
      dates = {
        Date.from_string('2021-05-22 Sat', {
          type = 'DEADLINE',
          active = true,
          range = Range:new({
            start_line = 5,
            end_line = 5,
            start_col = 11,
            end_col = 26
          }),
        }),
      },
      range = Range:new({
        start_line = 5,
        end_line = 5,
      }),
      id = 5,
      parent = 3,
      type = Types.PLANNING,
    }, parsed.items[5])
  end)
end)
