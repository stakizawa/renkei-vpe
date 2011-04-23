$: << File.join(File.dirname(__FILE__), '..', '..', 'lib')

require 'test/unit'
require 'pp'
require 'renkei-vpe-server/resource_file'

class ConfigTest < Test::Unit::TestCase
  include RenkeiVPE::ResourceFile

  def setup
    @yaml1_h_only =<<EOS
Aa: a
bB: b
c1: c
D2: d
EOS

    @yaml2_a_only =<<EOS
- a
- b
- c
EOS

    @yaml3_ha =<<EOS
Aa: a
bB:
 - 1
 - 2
EOS

    @yaml4_hah =<<EOS
Aa: a
bB:
 - 1
 - 2
c1:
 - 1a: x
   2b: y
 - a1: xx
   b2: yy
EOS

    @yaml5_haha =<<EOS
Aa: a
bB:
 - 1
 - 2
c1:
 - 1a: x
   2b: y
 - a1: xx
   b2: yy
   c3:
    - xxx
    - yyy
EOS
  end


  def test_load_yaml_with_yaml1
    obj = Parser.load_yaml(@yaml1_h_only)
    assert_equal(Hash, obj.class)
    assert_equal('a', obj['AA'])
    assert_equal('b', obj['BB'])
    assert_equal('c', obj['C1'])
    assert_equal('d', obj['D2'])
  end

  def test_load_yaml_with_yaml2
    obj = Parser.load_yaml(@yaml2_a_only)
    assert_equal(Array, obj.class)
    assert_equal('a', obj[0])
    assert_equal('b', obj[1])
    assert_equal('c', obj[2])
  end

  def test_load_yaml_with_yaml3
    obj = Parser.load_yaml(@yaml3_ha)
    assert_equal(Hash, obj.class)
    assert_equal('a', obj['AA'])
    assert_equal(Array, obj['BB'].class)

    ary = obj['BB']
    assert_equal(1, ary[0])
    assert_equal(2, ary[1])
  end

  def test_load_yaml_with_yaml4
    obj = Parser.load_yaml(@yaml4_hah)
    assert_equal(Hash, obj.class)
    assert_equal('a', obj['AA'])
    assert_equal(Array, obj['BB'].class)

    ary = obj['BB']
    assert_equal(1, ary[0])
    assert_equal(2, ary[1])
    assert_equal(Array, obj['C1'].class)

    ary = obj['C1']

    assert_equal(Hash, ary[0].class)
    hash = ary[0]
    assert_equal('x', hash['1A'])
    assert_equal('y', hash['2B'])

    assert_equal(Hash, ary[1].class)
    hash = ary[1]
    assert_equal('xx', hash['A1'])
    assert_equal('yy', hash['B2'])
  end

  def test_load_yaml_with_yaml5
    obj = Parser.load_yaml(@yaml5_haha)
    assert_equal(Hash, obj.class)
    assert_equal('a', obj['AA'])
    assert_equal(Array, obj['BB'].class)

    ary = obj['BB']
    assert_equal(1, ary[0])
    assert_equal(2, ary[1])
    assert_equal(Array, obj['C1'].class)

    ary = obj['C1']

    assert_equal(Hash, ary[0].class)
    hash = ary[0]
    assert_equal('x', hash['1A'])
    assert_equal('y', hash['2B'])

    assert_equal(Hash, ary[1].class)
    hash = ary[1]
    assert_equal('xx', hash['A1'])
    assert_equal('yy', hash['B2'])

    assert_equal(Array, hash['C3'].class)
    ary = hash['C3']
    assert_equal('xxx', ary[0])
    assert_equal('yyy', ary[1])
  end
end


# Local Variables:
# mode: Ruby
# coding: utf-8-unix
# indent-tabs-mode: nil
# End:
