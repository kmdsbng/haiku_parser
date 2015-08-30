# -*- encoding: utf-8 -*-
require 'natto'
require 'pry'

class PatternMatchProgress
  attr_reader :match_start, :token_pos, :rule_pos, :sentence, :rule

  def initialize(match_start, token_pos, rule_pos, sentence, rule)
    @match_start = match_start
    @token_pos = token_pos
    @rule_pos = rule_pos
    @sentence = sentence
    @rule = rule
  end

  def self.progress_start(match_start, token_pos)
    PatternMatchProgress.new(match_start, token_pos, 0, "", make_rule)
  end

  def self.make_rule
    [5, 7, 5].dup
  end
end

class Haiku
  def initialize(body)
    @body = body
  end

  def reIgnoreText
    /[\[\]「」『』]/
  end

  def reIgnoreChar
    /[ァィゥェォャュョ]/
  end

  def reWord
    /^[ァ-ヾ]+$/
  end

  def make_rule
    [5, 7, 5].dup
  end

  def isWord(features)
    ["名詞", "動詞", "形容詞", "形容動詞", "副詞", "連体詞", "接続詞", "感動詞", "接頭詞", "フィラー"].include?(features[0]) &&
      features[1] != '非自立' &&
      features[1] != '接尾'
  end

  def count_char(kana)
    kana.gsub(reIgnoreChar, '').length
  end

  def find(&block)
    ret = []
    nm = Natto::MeCab.new
    body = @body.gsub(reIgnoreText, '')
    tokens = nm.enum_parse(body).to_a
    pos = 0
    sentence = ""
    rule = make_rule
    i = 0
    progress = nil
    while(i < tokens.length)
      token = tokens[i]
      i += 1
      progress = PatternMatchProgress.new(
        progress.match_start, progress.token_pos + 1, progress.rule_pos, progress.sentence,
        progress.rule) if progress

      if progress && i != progress.token_pos
        raise "guard 0.1: #{i}, #{progress.token_pos}"
      end

      features = token.feature.split(',')
      y = features.last
      if reWord !~ y
        if y == '、'
          next
        end
        pos = 0
        sentence = ""
        progress = nil
        next
      end
      if progress && progress.rule[pos] == rule[pos] && !isWord(features)
        # rewind_to(start + 1)
        i = progress.match_start + 1
        pos = 0
        sentence = ""
        progress = nil
        next
      end

      if progress && progress.rule[pos] == rule[pos] && pos == 0
        raise 'guard 1' if progress
      end

      unless progress
        progress = PatternMatchProgress.progress_start(i - 1, i)
      end
      n = count_char(y)
      sentence += token.surface

      progress = PatternMatchProgress.new(
        progress.match_start, progress.token_pos, progress.rule_pos, progress.sentence + token.surface,
        progress.rule.map.with_index {|part, m| m == progress.rule_pos ? part - n : part})

      if pos != progress.rule_pos
        raise "guard 2: #{pos}, #{progress.rule_pos}"
      end

      if progress.rule[pos] == 0
        pos += 1

        progress = PatternMatchProgress.new(
          progress.match_start, progress.token_pos, progress.rule_pos + 1, progress.sentence,
          progress.rule)

        if pos != progress.rule_pos
          raise "guard 2.5"
        end

        if pos >= progress.rule.length
          if progress.sentence != sentence
            raise "guard 3: '#{progress.sentence}', '#{sentence}'"
          end

          ret << sentence
          yield sentence if block
          pos = 0
          sentence = ""
          progress = nil
          next
        end
        sentence += ' '
        progress = PatternMatchProgress.new(
          progress.match_start, progress.token_pos, progress.rule_pos, progress.sentence + ' ',
          progress.rule)
      elsif progress.rule[pos] < 0
        i = progress.match_start + 1
        pos = 0
        sentence = ""
        progress = nil
      end
    end
    ret
  end
end

def main
  if File.pipe?(STDIN) || File.select([STDIN], [], [], 0) != nil then
    str = STDIN.read
  else
    str = "ああ柿くへば鐘が鳴るなり法隆寺"
  end

  #nm = Natto::MeCab.new
  #puts nm.parse(str)

  haiku = Haiku.new(str)
  haiku.find {|found|
    puts found
  }
end

case $PROGRAM_NAME
when __FILE__
  main
when /spec[^\/]*$/
  describe Haiku do
    it "啄木OK1" do
      str = "ああ柿くへば鐘が鳴るなり法隆寺"
      expect(Haiku.new(str).find).to eq(["柿くへば 鐘が鳴るなり 法隆寺"])
    end

    it "啄木OK2" do
      str = "柿くへば鐘が鳴るなり法隆寺"
      expect(Haiku.new(str).find).to eq(["柿くへば 鐘が鳴るなり 法隆寺"])
    end

    it "芭蕉OK" do
      str = "古池や蛙飛び込む水の音"
      expect(Haiku.new(str).find).to eq(["古池や 蛙飛び込む 水の音"])
    end

    it "ハノイの塔OK" do
      str = "円盤を動かすことで解答が"
      expect(Haiku.new(str).find).to eq(["円盤を 動かすことで 解答が"])
    end
  end
end

# >> ああ	感動詞,*,*,*,*,*,ああ,アア,アー
# >> 柿	名詞,一般,*,*,*,*,柿,カキ,カキ
# >> く	動詞,非自立,*,*,五段・カ行促音便,基本形,く,ク,ク
# >> へ	助詞,格助詞,一般,*,*,*,へ,ヘ,エ
# >> ば	助詞,接続助詞,*,*,*,*,ば,バ,バ
# >> 鐘	名詞,一般,*,*,*,*,鐘,カネ,カネ
# >> が	助詞,格助詞,一般,*,*,*,が,ガ,ガ
# >> 鳴る	動詞,自立,*,*,五段・ラ行,基本形,鳴る,ナル,ナル
# >> なり	助詞,接続助詞,*,*,*,*,なり,ナリ,ナリ
# >> 法隆寺	名詞,固有名詞,組織,*,*,*,法隆寺,ホウリュウジ,ホーリュージ
# >> EOS
# >> [1, "ああ柿く"]
# >> [1, "鐘が鳴る"]
# >> [1, "法隆寺"]
