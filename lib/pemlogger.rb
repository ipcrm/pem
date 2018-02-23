require 'logger'


module PemLogger
  LOGGER = Logger.new(STDOUT)

  def self.logit(msg, level=:info)
    # Set log level
    log_level = level.class == Symbol ? level : level.to_sym

    # Parse caller
    called_by = caller[0].split('/')[-1]

    case log_level
    when :fatal
      LOGGER.fatal(called_by) { 'Caught exception; exiting' }
      LOGGER.fatal("\n" + msg.to_s)
    when :debug
      LOGGER.debug(called_by) { msg }
    else
      LOGGER.info(called_by) { msg }
    end
  end
end
