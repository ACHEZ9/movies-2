class MovieData
	attr_reader :training_set, :test_set, :most_similar_hash

	def initialize(path, base_test_pair = nil)
		@training_set = {users:{}, movies:{}}
		@test_set = []
		@most_similar_hash = {}
		read_files(path, base_test_pair)
	end

#Given the path to the dir, and the base/test pair or nil, loads the data from the files
	def read_files(path, base_test_pair)
		if base_test_pair == nil
			load_data(training_set, path + "/u.data")
		else
			load_data(training_set, path + "/#{base_test_pair}.base")
			# load_data(test_set, path + "/#{base_test_pair}.test")
			load_test_data(path + "/#{base_test_pair}.test")
		end
	end

#loads the test file into an array, each row/element a hash
	def load_test_data(file)
		data = open(file)
		data.each_line do |line|
			row = line.split("\t")
			user_id, movie_id, rating, timeStamp = row
			test_set.push({user_id:user_id, movie_id:movie_id, rating:rating.to_i})
		end
	end

#loads the appropriate set with the corresponding file path
	def load_data(set, file)
		users_hash = set[:users]
		movies_hash = set[:movies]
		data = open(file)
		data.each_line do |line|
			process_line(line, users_hash, movies_hash)
		end
		data.close
	end

#processes each line of the file, storing the appropriate data in the two hashes
	def process_line(line, users_hash, movies_hash)
		row = line.split("\t")
		user_id, movie_id, rating, timeStamp = row

		if users_hash.has_key?(user_id)
			users_hash[user_id][movie_id] = rating.to_i
		else
			users_hash[user_id] = {movie_id => rating.to_i}
		end

		if movies_hash.has_key?(movie_id)
			movies_hash[movie_id][:rating] += rating.to_i
			movies_hash[movie_id][:count] += 1
			movies_hash[movie_id][:viewers].push(user_id)
		else
			movies_hash[movie_id] = {rating:rating.to_i, count:1, viewers: [user_id]}
		end
	end

#returns the rating user with user_id has given to the movie with movie_id
#0 if has not seen
	def rating(user_id, movie_id)
		user_movie_hash = movies(user_id)
		if user_movie_hash.has_key?(movie_id)
			user_movie_hash[movie_id]
		else
			0
		end
	end

#returns the users who have watched the given movie
	def viewers(movie_id)
		movie_hash = training_set[:movies][movie_id]
		movie_hash[:viewers]
	end

#returns the hash of {movie_id => rating} for the given user
	def movies(user_id)
		training_set[:users][user_id]
	end

#prediction based on the average rating for the most similar users
#excludes similar users that did not see the movie
	def predict(user_id, movie_id)
		similar_users = most_similar(user_id)
		total_rating = 0
		count = 0
		similar_users.each do |user_id|
			user_rating = rating(user_id, movie_id)
			if user_rating != 0
				total_rating += user_rating
				count += 1
			end
		end
		if count != 0
			total_rating.to_f/count
		else
			0
		end
	end

#returns the similarity between two users, higher number is more similar
#userIds are Strings
	def similarity(user1, user2)
		similarity = 0
		user1_movie_hash = movies(user1)
		user2_movie_hash = movies(user2)

		user1_movie_hash.each do |movie_id, rating|
			if user2_movie_hash.has_key?(movie_id)
				rating_diff = rating - rating(user2, movie_id)
				similarity += (1 - rating_diff/3.0)
			end
		end

		return similarity
	end

#Will return the most similar users to user_id, based on similarity
	def most_similar(user_id, num_of_results = 50)
		if !most_similar_hash.has_key? (user_id)
			tempArray = training_set[:users].sort_by {|user_id2, value| self.similarity(user_id,user_id2)}.reverse
			similarity_list = []

			tempArray.each do |array|
				user_id2 = array.first
				if user_id != user_id2
					similarity_list.push(user_id2)
				end
			end
			most_similar_hash[user_id] = similarity_list[0..num_of_results]
		end

		return most_similar_hash[user_id]
	end

#runs the prediction algorithm on the first n number of samples in the test set
	def run_test(sample_size = test_set.size)
		count = 0
		movie_test_object = MovieTest.new()

		start_time = Time.now
		test_set.each do |hash|
			if count == sample_size
				break
			else
				count += 1
				user_id = hash[:user_id]
				movie_id = hash[:movie_id]
				rating = hash[:rating]
				prediction = predict(user_id, movie_id)
				movie_test_object.add_prediction({user_id:user_id, movie_id:movie_id, rating:rating, prediction:prediction})
			end
		end
		end_time = Time.now

		movie_test_object.run_time = end_time - start_time

		return movie_test_object
	end
end

class MovieTest
	attr_accessor :predictions, :run_time

	def initialize()
		@predictions = []
		@run_time
	end

	def add_prediction(prediction)
		predictions.push(prediction)
	end

	def to_a()
		prediction_array = []
		predictions.each do |hash|
			prediction_array.push([hash[:user_id], hash[:movie_id], hash[:rating], hash[:prediction]])
		end

		return prediction_array
	end

#returns the mean error between prediction and actual rating
	def mean()
		total_error = 0
		count = 0
		predictions.each do |hash|
			total_error += error(hash)
			count += 1
		end

		return total_error/count.to_f
	end

#returns the difference between the actual and predicited rating for a prediciton
	def error(prediction)
		(prediction[:rating] - prediction[:prediction]).abs
	end

	def stddev()
		mean = self.mean()
		sum_of_sq = 0
		predictions.each do |prediction|
			sum_of_sq += ((error(prediction) - mean)**2)
		end

		Math.sqrt(sum_of_sq.to_f/predictions.count)
	end

	def rms()
		sum_of_sq = 0
		predictions.each do |prediction|
			sum_of_sq += (error(prediction))**2
		end

		Math.sqrt(sum_of_sq.to_f/predictions.count)
	end

	def time_to_run()
		puts "The time it took to run #{predictions.count} predictions, was #{run_time} seconds"
	end
end

###########Testing
movie_data = MovieData.new("ml-100k", :u1)
n = 20000
movie_test = movie_data.run_test()
puts "The test was run on the first #{n} samples from u1"
puts "The average prediction error is #{movie_test.mean}"
puts "The standard deviation of the errors is #{movie_test.stddev}"
puts "The RMSE of the prediction is #{movie_test.rms}"
movie_test.time_to_run

