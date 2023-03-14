module Git
  class Base
    def remote_show_origin
      lib.remote_show_origin
    end

    def submodule_update
      lib.submodule_update
    end
  end

  class Lib
    def branches_all
      arr = []
      count = 0

      command_lines('branch', ['-a', '--sort=-authordate']).each do |b|
        current = (b[0, 2] == '* ')
        arr << [b.gsub('* ', '').strip, current]
        count += 1

        break if count == Settings.slack.interactive.branch_limit
      end
      arr
    end

    def tags
      arr = []
      count = 0

      command_lines('tag', ['--sort=-v:refname']).each do |t|
        arr << t
        count += 1

        break if count == Settings.slack.interactive.tag_limit
      end
      arr
    end

    def submodule_update
      command("-C #{@git_work_dir} submodule update --init")
      command("-C #{@git_work_dir} submodule update --remote")
    end

    def remote_show_origin
      command('remote show origin')
    end
  end
end
