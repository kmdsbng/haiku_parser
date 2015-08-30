# -*- encoding: utf-8 -*-
require 'natto'

class PatternMatchProgress
  attr_reader :rule_pos, :rule, :default_rule, :sentences

  def initialize(rule_pos, sentences, rule, default_rule)
    @rule_pos = rule_pos
    @sentences = sentences
    @rule = rule
    @default_rule = default_rule
  end

  ### ClassMethods
  def self.make_rule
    [5, 7, 5].dup
  end

  ### FactoryMethods
  def self.progress_start
    PatternMatchProgress.new(0, [''], make_rule, make_rule)
  end

  def add_sentence(new_sentence, char_count)
    PatternMatchProgress.new(
      self.rule_pos,
      self.sentences[0..-2] + [self.sentences[-1] + new_sentence],
      self.rule.map.with_index {|part, m| m == self.rule_pos ? part - char_count : part},
      self.default_rule)
  end

  def mark_word_break
    PatternMatchProgress.new(self.rule_pos + 1, self.sentences + [''], self.rule, self.default_rule)
  end

  ### InstanceMethods
  def word_start?
    self.rule[self.rule_pos] == self.default_rule[self.rule_pos]
  end

  def matched?
    self.rule_pos >= self.rule.length
  end

  def sentence
    self.sentences.reject(&:empty?).join(' ')
  end

  def word_length_matched?
    self.rule[self.rule_pos] == 0
  end

  def word_length_over?
    self.rule[self.rule_pos] < 0
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

  def jiritu_token?(features)
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
    tokens.length.times do |i|
      matched_sentence = try_to_match(tokens, i)
      if matched_sentence
        yield matched_sentence if block
        ret << matched_sentence
      end
    end
    ret
  end

  # check sentence from tokens[match_start] match rule.
  #
  # retval: matched sentence
  def try_to_match(tokens, match_start)
    progress = PatternMatchProgress.progress_start
    (match_start...tokens.length).each do |i|
      token = tokens[i]
      features = token.feature.split(',')
      y = features.last
      if reWord !~ y
        if y == '、'
          next
        end
        return nil
      end
      if progress.word_start? && !jiritu_token?(features)
        return nil
      end
      n = count_char(y)
      progress = progress.add_sentence(token.surface, n)

      if progress.word_length_matched?
        progress = progress.mark_word_break
      elsif progress.word_length_over?
        return nil
      end
      return progress.sentence if progress.matched?
    end
    nil
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
