local unicodeToCC = {
  [9216] = 0,
  [0] = 0,
  [9786] = 1,
  [9787] = 2,
  [9829] = 3,
  [9830] = 4,
  [9827] = 5,
  [9824] = 6,
  [8226] = 7,
  [9688] = 8,
  [9] = 9,
  [10] = 10,
  [9794] = 11,
  [9792] = 12,
  [13] = 13,
  [9834] = 14,
  [9835] = 15,
  [9654] = 16,
  [9664] = 17,
  [11021] = 18,
  [8252] = 19,
  [57345] = 20,
  [57346] = 21,
  [9602] = 22,
  [8616] = 23,
  [8593] = 24,
  [8595] = 25,
  [8594] = 26,
  [8592] = 27,
  [8985] = 28,
  [11020] = 29,
  [9650] = 30,
  [9660] = 31,
  [9618] = 127,
  [10240] = 128,
  [10241] = 129,
  [10248] = 130,
  [10249] = 131,
  [10242] = 132,
  [10243] = 133,
  [10250] = 134,
  [10251] = 135,
  [10256] = 136,
  [10257] = 137,
  [10264] = 138,
  [10265] = 139,
  [10258] = 140,
  [10259] = 141,
  [10266] = 142,
  [10267] = 143,
  [10244] = 144,
  [10245] = 145,
  [10252] = 146,
  [10253] = 147,
  [10246] = 148,
  [10247] = 149,
  [10254] = 150,
  [10255] = 151,
  [10260] = 152,
  [10261] = 153,
  [10268] = 154,
  [10269] = 155,
  [10262] = 156,
  [10263] = 157,
  [10271] = 158,
  [10272] = 159,
  [32] = 32,
  [33] = 33,
  [34] = 34,
  [35] = 35,
  [36] = 36,
  [37] = 37,
  [38] = 38,
  [39] = 39,
  [40] = 40,
  [41] = 41,
  [42] = 42,
  [43] = 43,
  [44] = 44,
  [45] = 45,
  [46] = 46,
  [47] = 47,
  [48] = 48,
  [49] = 49,
  [50] = 50,
  [51] = 51,
  [52] = 52,
  [53] = 53,
  [54] = 54,
  [55] = 55,
  [56] = 56,
  [57] = 57,
  [58] = 58,
  [59] = 59,
  [60] = 60,
  [61] = 61,
  [62] = 62,
  [63] = 63,
  [64] = 64,
  [65] = 65,
  [66] = 66,
  [67] = 67,
  [68] = 68,
  [69] = 69,
  [70] = 70,
  [71] = 71,
  [72] = 72,
  [73] = 73,
  [74] = 74,
  [75] = 75,
  [76] = 76,
  [77] = 77,
  [78] = 78,
  [79] = 79,
  [80] = 80,
  [81] = 81,
  [82] = 82,
  [83] = 83,
  [84] = 84,
  [85] = 85,
  [86] = 86,
  [87] = 87,
  [88] = 88,
  [89] = 89,
  [90] = 90,
  [91] = 91,
  [92] = 92,
  [93] = 93,
  [94] = 94,
  [95] = 95,
  [96] = 96,
  [97] = 97,
  [98] = 98,
  [99] = 99,
  [100] = 100,
  [101] = 101,
  [102] = 102,
  [103] = 103,
  [104] = 104,
  [105] = 105,
  [106] = 106,
  [107] = 107,
  [108] = 108,
  [109] = 109,
  [110] = 110,
  [111] = 111,
  [112] = 112,
  [113] = 113,
  [114] = 114,
  [115] = 115,
  [116] = 116,
  [117] = 117,
  [118] = 118,
  [119] = 119,
  [120] = 120,
  [121] = 121,
  [122] = 122,
  [123] = 123,
  [124] = 124,
  [125] = 125,
  [126] = 126,
  [160] = 160,
  [161] = 161,
  [162] = 162,
  [163] = 163,
  [164] = 164,
  [165] = 165,
  [166] = 166,
  [167] = 167,
  [168] = 168,
  [169] = 169,
  [170] = 170,
  [171] = 171,
  [172] = 172,
  [173] = 173,
  [174] = 174,
  [175] = 175,
  [176] = 176,
  [177] = 177,
  [178] = 178,
  [179] = 179,
  [180] = 180,
  [181] = 181,
  [182] = 182,
  [183] = 183,
  [184] = 184,
  [185] = 185,
  [186] = 186,
  [187] = 187,
  [188] = 188,
  [189] = 189,
  [190] = 190,
  [191] = 191,
  [192] = 192,
  [193] = 193,
  [194] = 194,
  [195] = 195,
  [196] = 196,
  [197] = 197,
  [198] = 198,
  [199] = 199,
  [200] = 200,
  [201] = 201,
  [202] = 202,
  [203] = 203,
  [204] = 204,
  [205] = 205,
  [206] = 206,
  [207] = 207,
  [208] = 208,
  [209] = 209,
  [210] = 210,
  [211] = 211,
  [212] = 212,
  [213] = 213,
  [214] = 214,
  [215] = 215,
  [216] = 216,
  [217] = 217,
  [218] = 218,
  [219] = 219,
  [220] = 220,
  [221] = 221,
  [222] = 222,
  [223] = 223,
  [224] = 224,
  [225] = 225,
  [226] = 226,
  [227] = 227,
  [228] = 228,
  [229] = 229,
  [230] = 230,
  [231] = 231,
  [232] = 232,
  [233] = 233,
  [234] = 234,
  [235] = 235,
  [236] = 236,
  [237] = 237,
  [238] = 238,
  [239] = 239,
  [240] = 240,
  [241] = 241,
  [242] = 242,
  [243] = 243,
  [244] = 244,
  [245] = 245,
  [246] = 246,
  [247] = 247,
  [248] = 248,
  [249] = 249,
  [250] = 250,
  [251] = 251,
  [252] = 252,
  [253] = 253,
  [254] = 254,
  [255] = 255
}
local ccToUnicode = {
  [0] = 0,
  [1] = 9786,
  [2] = 9787,
  [3] = 9829,
  [4] = 9830,
  [5] = 9827,
  [6] = 9824,
  [7] = 8226,
  [8] = 9688,
  [9] = 9,
  [10] = 10,
  [11] = 9794,
  [12] = 9792,
  [13] = 13,
  [14] = 9834,
  [15] = 9835,
  [16] = 9654,
  [17] = 9664,
  [18] = 11021,
  [19] = 8252,
  [20] = 57345,
  [21] = 57346,
  [22] = 9602,
  [23] = 8616,
  [24] = 8593,
  [25] = 8595,
  [26] = 8594,
  [27] = 8592,
  [28] = 8985,
  [29] = 11020,
  [30] = 9650,
  [31] = 9660,
  [127] = 9618,
  [128] = 10240,
  [129] = 10241,
  [130] = 10248,
  [131] = 10249,
  [132] = 10242,
  [133] = 10243,
  [134] = 10250,
  [135] = 10251,
  [136] = 10256,
  [137] = 10257,
  [138] = 10264,
  [139] = 10265,
  [140] = 10258,
  [141] = 10259,
  [142] = 10266,
  [143] = 10267,
  [144] = 10244,
  [145] = 10245,
  [146] = 10252,
  [147] = 10253,
  [148] = 10246,
  [149] = 10247,
  [150] = 10254,
  [151] = 10255,
  [152] = 10260,
  [153] = 10261,
  [154] = 10268,
  [155] = 10269,
  [156] = 10262,
  [157] = 10263,
  [158] = 10271,
  [159] = 10272,
  [32] = 32,
  [33] = 33,
  [34] = 34,
  [35] = 35,
  [36] = 36,
  [37] = 37,
  [38] = 38,
  [39] = 39,
  [40] = 40,
  [41] = 41,
  [42] = 42,
  [43] = 43,
  [44] = 44,
  [45] = 45,
  [46] = 46,
  [47] = 47,
  [48] = 48,
  [49] = 49,
  [50] = 50,
  [51] = 51,
  [52] = 52,
  [53] = 53,
  [54] = 54,
  [55] = 55,
  [56] = 56,
  [57] = 57,
  [58] = 58,
  [59] = 59,
  [60] = 60,
  [61] = 61,
  [62] = 62,
  [63] = 63,
  [64] = 64,
  [65] = 65,
  [66] = 66,
  [67] = 67,
  [68] = 68,
  [69] = 69,
  [70] = 70,
  [71] = 71,
  [72] = 72,
  [73] = 73,
  [74] = 74,
  [75] = 75,
  [76] = 76,
  [77] = 77,
  [78] = 78,
  [79] = 79,
  [80] = 80,
  [81] = 81,
  [82] = 82,
  [83] = 83,
  [84] = 84,
  [85] = 85,
  [86] = 86,
  [87] = 87,
  [88] = 88,
  [89] = 89,
  [90] = 90,
  [91] = 91,
  [92] = 92,
  [93] = 93,
  [94] = 94,
  [95] = 95,
  [96] = 96,
  [97] = 97,
  [98] = 98,
  [99] = 99,
  [100] = 100,
  [101] = 101,
  [102] = 102,
  [103] = 103,
  [104] = 104,
  [105] = 105,
  [106] = 106,
  [107] = 107,
  [108] = 108,
  [109] = 109,
  [110] = 110,
  [111] = 111,
  [112] = 112,
  [113] = 113,
  [114] = 114,
  [115] = 115,
  [116] = 116,
  [117] = 117,
  [118] = 118,
  [119] = 119,
  [120] = 120,
  [121] = 121,
  [122] = 122,
  [123] = 123,
  [124] = 124,
  [125] = 125,
  [126] = 126,
  [160] = 160,
  [161] = 161,
  [162] = 162,
  [163] = 163,
  [164] = 164,
  [165] = 165,
  [166] = 166,
  [167] = 167,
  [168] = 168,
  [169] = 169,
  [170] = 170,
  [171] = 171,
  [172] = 172,
  [173] = 173,
  [174] = 174,
  [175] = 175,
  [176] = 176,
  [177] = 177,
  [178] = 178,
  [179] = 179,
  [180] = 180,
  [181] = 181,
  [182] = 182,
  [183] = 183,
  [184] = 184,
  [185] = 185,
  [186] = 186,
  [187] = 187,
  [188] = 188,
  [189] = 189,
  [190] = 190,
  [191] = 191,
  [192] = 192,
  [193] = 193,
  [194] = 194,
  [195] = 195,
  [196] = 196,
  [197] = 197,
  [198] = 198,
  [199] = 199,
  [200] = 200,
  [201] = 201,
  [202] = 202,
  [203] = 203,
  [204] = 204,
  [205] = 205,
  [206] = 206,
  [207] = 207,
  [208] = 208,
  [209] = 209,
  [210] = 210,
  [211] = 211,
  [212] = 212,
  [213] = 213,
  [214] = 214,
  [215] = 215,
  [216] = 216,
  [217] = 217,
  [218] = 218,
  [219] = 219,
  [220] = 220,
  [221] = 221,
  [222] = 222,
  [223] = 223,
  [224] = 224,
  [225] = 225,
  [226] = 226,
  [227] = 227,
  [228] = 228,
  [229] = 229,
  [230] = 230,
  [231] = 231,
  [232] = 232,
  [233] = 233,
  [234] = 234,
  [235] = 235,
  [236] = 236,
  [237] = 237,
  [238] = 238,
  [239] = 239,
  [240] = 240,
  [241] = 241,
  [242] = 242,
  [243] = 243,
  [244] = 244,
  [245] = 245,
  [246] = 246,
  [247] = 247,
  [248] = 248,
  [249] = 249,
  [250] = 250,
  [251] = 251,
  [252] = 252,
  [253] = 253,
  [254] = 254,
  [255] = 255
}

local export = {}

function export.convertToUnicode(s, convertNull)
  local res = {}
  for i=1,#s do
    local c = string.byte(s, i)
    local codepoint = ccToUnicode[c]
    if convertNull and c == 0 then
      codepoint = 0x2400 -- U+2400 "symbol for null"
    elseif codepoint == nil then
      error("cc to unicode should cover entire set")
    end
    local str
    if codepoint < 0x80 then
      str = string.char(codepoint)
    elseif codepoint < 0x800 then
      str = string.char(
        bit.blogic_rshift(codepoint, 6) + 0xc0,
        bit.band(codepoint, 0x3f) + 0x80
      )
    elseif codepoint < 0x10000 then
      str = string.char(
        bit.blogic_rshift(codepoint, 12) + 0xe0,
        bit.band(bit.blogic_rshift(codepoint, 6), 0x3f) + 0x80,
        bit.band(codepoint, 0x3f) + 0x80
      )
    elseif codepoint < 0x10ffff then
      str = string.char(
        bit.blogic_rshift(codepoint, 18) + 0xf0,
        bit.band(bit.blogic_rshift(codepoint, 12), 0x3f) + 0x80,
        bit.band(bit.blogic_rshift(codepoint, 6), 0x3f) + 0x80,
        bit.band(codepoint, 0x3f) + 0x80
      )
    else
      error("codepoint out of range")
    end
    res[i] = str
  end
  return table.concat(res)
end

function export.convertToCC(s)
  local res = {}
  local len = #s
  local byteidx = 1
  local codepointidx = 1
  while byteidx <= len do
    --print(byteidx)
    local c = string.byte(s, byteidx)
    byteidx = byteidx + 1
    local unicode
    if bit.band(c, 0x80) == 0 then --single byte
      unicode = c
    elseif bit.band(c, 0x40) == 0 then
      error("malformed UTF-8")
    elseif bit.band(c, 0x20) == 0 then -- 2-byte
      local other = string.byte(s, byteidx)
      byteidx = byteidx + 1
      if bit.band(other, 0xc0) ~= 0x80 then
        error("malformed UTF-8")
      end
      unicode = bit.blshift(bit.band(c, 0x1F), 6) + bit.band(other, 0x3f)
    elseif bit.band(c, 0x10) == 0 then -- 3-byte
      local other1 = string.byte(s, byteidx)
      byteidx = byteidx + 1
      local other2 = string.byte(s, byteidx)
      byteidx = byteidx + 1
      if bit.band(other1, 0xc0) ~= 0x80 or bit.band(other2, 0xc0) ~= 0x80 then
        error("malformed UTF-8")
      end
      unicode = 
        bit.blshift(bit.band(c, 0x0F), 12) +
        bit.blshift(bit.band(other1, 0x3F), 6) +
        bit.band(other2, 0x3F)
    elseif bit.band(c, 0x08) == 0 then
      local other1 = string.byte(s, byteidx)
      byteidx = byteidx + 1
      local other2 = string.byte(s, byteidx)
      byteidx = byteidx + 1
      local other3 = string.byte(s, byteidx)
      byteidx = byteidx + 1
      if bit.band(other1, 0xc0) ~= 0x80 or bit.band(other2, 0xc0) ~= 0x80 or bit.band(other3, 0xc0) ~= 0x80 then
        error("malformed UTF-8")
      end
      unicode =
        bit.blshift(bit.band(c, 0x04), 18) +
        bit.blshift(bit.band(other1, 0x3F), 12) +
        bit.blshift(bit.band(other2, 0x3F), 6) +
        bit.band(other3, 0x3F)
    else
      -- The unicode consortium pinky promised that humanity will never need more than ~20 million characters.
      error("malformed UTF-8")
    end
    local cc = unicodeToCC[unicode]
    if cc == nil then
      cc = 8 -- inverted bullet, I dunno, seems like as good a replacement symbol out of the available set.
    end
    res[codepointidx] = string.char(cc)
    codepointidx = codepointidx + 1
  end
  return table.concat(res)
end

-- Returns true iff the string `s` is exactly the same in both UTF-8 and CC, true only for all printable ascii.
function export.symmetric(s)
  for i=1,#s do
    local b = string.byte(s,i)
    if (b < 32 or b > 126) and b ~= 10 and b ~= 13 and b ~= 9 then
      return false
    end
  end
  return true
end

return export
