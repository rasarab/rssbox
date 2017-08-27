# https://github.com/speedruncom/api/tree/master/version1

class Speedrun < HTTP
  BASE_URL = "https://www.speedrun.com/api/v1"

  @@cache = {}

  def self.resolve_id(type, id)
    @@cache[type] ||= {}
    return @@cache[type][id] if @@cache[type][id]
    value = $redis.hget("speedrun", "#{type}:#{id}")
    if value
      @@cache[type][id] = if type == "level-subcategories"
        JSON.parse(value)
      else
        value
      end
      return @@cache[type][id]
    end

    if type == "game"
      response = Speedrun.get("/games/#{id}")
      raise SpeedrunError.new(response) if !response.success?
      redis_value = value = response.json["data"]["names"]["international"]
    elsif type == "level-subcategories"
      response = Speedrun.get("/levels/#{id}/variables")
      raise SpeedrunError.new(response) if !response.success?
      value = response.json["data"].select { |var| var["is-subcategory"] }.map do |var|
        [
          var["id"],
          var["values"]["values"].map do |id, val|
            [id, val["label"]]
          end.to_h
        ]
      end.to_h
      redis_value = value.to_json
    end

    $redis.hset("speedrun", "#{type}:#{id}", redis_value)
    @@cache[type][id] = value
    return value
  end
end

class SpeedrunError < HTTPError; end

error SpeedrunError do |e|
  status 503
  "There was a problem talking to speedrun.com."
end