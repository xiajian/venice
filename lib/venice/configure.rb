# -*- encoding : utf-8 -*-
require 'logger'

module Venice
  module Configure
    # 日志记录
    mattr_accessor :logger
    self.logger = Logger.new(STDOUT)

    # 用来控制日志的打印输入的状态
    mattr_accessor :debug
    self.debug = true
  end
end
