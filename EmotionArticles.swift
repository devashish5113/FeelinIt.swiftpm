import Foundation

// MARK: - Article Model

struct ArticleSection: Identifiable {
    let id = UUID()
    let heading: String   // sub-heading shown in bold (empty = body-only paragraph)
    let body: String
}

struct EmotionArticle: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String          // One-liner shown on the browse card
    let thumbnailName: String     // Asset name — user will provide; show placeholder if missing
    let readTime: String
    let source: String
    let sourceURL: String
    let sections: [ArticleSection]
}

// MARK: - Per-Emotion Data

extension Emotion {
    var articles: [EmotionArticle] {
        switch self {

        // ════════════════════════════════════════════════════════════════
        // CALM
        // ════════════════════════════════════════════════════════════════
        case .calm:
            return [

                EmotionArticle(
                    title: "Calmness Rewires Your Brain",
                    subtitle: "How tranquility reshapes your neural architecture.",
                    thumbnailName: "thumb_calm_rewires",
                    readTime: "4 min read",
                    source: "ELLE",
                    sourceURL: "https://elle.in/trending/the-science-of-tranquillity-how-calmness-rewires-your-brain-10955625",
                    sections: [
                        ArticleSection(heading: "", body: "When tranquillity sets in, the brain undergoes a subtle yet powerful chemical transformation. Stress activates the sympathetic nervous system, flooding the body with adrenaline and cortisol. Calmness, on the other hand, engages the parasympathetic system — allowing the brain to restore equilibrium. This shift improves communication between neurons and enhances emotional regulation, which is essential for maintaining mental stability during challenging situations."),
                        ArticleSection(heading: "The Brain Chemistry of Calm", body: "Serotonin levels rise during calm states, supporting mood balance and emotional steadiness. Dopamine activity becomes more regulated, improving motivation without triggering anxiety or restlessness. At the same time, inhibitory neurotransmitters such as GABA help slow racing thoughts, creating a sense of mental quiet. GABA is the brain's primary 'brake' chemical — it reduces neuronal excitability and is the same system targeted by anti-anxiety medications. When calmness is cultivated naturally, however, the brain learns to produce this effect without pharmaceutical intervention, making it a more durable path to emotional stability."),
                        ArticleSection(heading: "Cortisol and the Five-Minute Reset", body: "One of the most immediate benefits of tranquillity is its effect on cortisol. This stress hormone is essential in short bursts — helping us react to genuine threats — but when elevated for long periods, it impairs memory, disturbs sleep, and weakens emotional control. This is particularly relevant in high-stress environments, where constant demands keep the brain locked in alert mode. Scientific studies show that even brief moments of calmness can begin lowering cortisol within minutes. Slow breathing, intentional pauses, and focused attention signal safety to the brain, reducing stress hormone production. As cortisol levels drop, blood pressure stabilises, mental clarity improves, and emotional responses become more measured."),
                        ArticleSection(heading: "Mindfulness and Structural Brain Change", body: "Mindfulness psychology offers one of the clearest explanations of how tranquillity reshapes the brain long-term. Mindfulness involves paying deliberate, non-judgmental attention to the present moment — and neuroscience confirms that this simple practice creates both structural and functional brain changes. A well-known study published in Frontiers in Human Neuroscience found that consistent mindfulness practice increases grey matter density in regions associated with emotional regulation, empathy, and memory. By calming the amygdala — the brain's fear centre — mindfulness reduces emotional reactivity. At the same time, it strengthens the prefrontal cortex, which governs decision-making and self-control. These changes allow individuals to respond thoughtfully rather than react impulsively, making tranquillity a learned neurological skill rather than a fleeting mood."),
                        ArticleSection(heading: "Building the Calm Habit", body: "Through neuroplasticity, the brain adapts to repeated calm states — gradually building stronger networks that support long-term mental health. Oxytocin, the bonding hormone associated with trust and connection, is also released during tranquil states, strengthening social bonds and emotional resilience. This explains why individuals who practise calmness regularly tend to recover faster from emotional setbacks and manage stress more effectively. Tranquillity is not passivity — it is the active cultivation of a more balanced, adaptive nervous system.")
                    ]
                ),

                EmotionArticle(
                    title: "Your Nervous System's Brake Pedal",
                    subtitle: "The vagus nerve, vagal tone, and why they shape your calm.",
                    thumbnailName: "thumb_calm_vagus",
                    readTime: "4 min read",
                    source: "MYNeuroBalance",
                    sourceURL: "https://myneurobalance.com/the-nervous-systems-role-in-focus-calm-and-performance/",
                    sections: [
                        ArticleSection(heading: "", body: "True calm isn't the absence of activity — it's the presence of regulation. The autonomic nervous system operates like a car: the sympathetic nervous system is the accelerator, and the parasympathetic nervous system is the brake. Both are essential. The trouble comes when the accelerator stays pressed too long."),
                        ArticleSection(heading: "The Vagus Nerve: Your Body's Calm Cable", body: "The vagus nerve is the longest nerve in the body. It runs from the brainstem down through the chest into the gut, connecting the brain to the heart, lungs, and intestines. It forms the structural backbone of the parasympathetic 'rest and digest' system — regulating heart rate, digestion, breathing rate, and immune response. When the vagus nerve is active and healthy, it sends calming signals throughout the body, reducing inflammation and slowing a racing heart after stress passes."),
                        ArticleSection(heading: "Vagal Tone and Heart Rate Variability", body: "The concept of 'vagal tone' is crucial for understanding calm. A higher vagal tone means the vagus nerve is functioning robustly and can effectively apply the brakes after stress. Vagal tone is measured through heart rate variability (HRV) — the natural variation in time between heartbeats. High HRV reflects a well-balanced autonomic system: the heart can speed up when needed and slow down appropriately when the threat has passed. Low HRV is associated with anxiety, poor emotional regulation, and cardiovascular risk. Daily practices such as slow diaphragmatic breathing, cold-water face immersion, singing, and humming have all been shown to increase vagal tone and improve HRV."),
                        ArticleSection(heading: "The Optimal Arousal Zone", body: "Peak performance and deep wellbeing occur in what researchers call the 'optimal arousal zone' — a specific range of nervous system activation. Too little activation leads to sluggishness and disengagement; too much leads to anxiety and overwhelm. The goal is not to eliminate arousal but to regulate it. When the vagus nerve is well-toned, individuals move efficiently between states — activating focus when needed and returning to calm when the task is done. This dynamic flexibility is the hallmark of psychological resilience."),
                        ArticleSection(heading: "How to Train Your Brake Pedal", body: "Vagal tone can be strengthened deliberately. Slow breathing — particularly exhales that are longer than inhales — directly activates the parasympathetic system. Cold exposure stimulates the vagus nerve through temperature receptors. Social engagement, laughter, and singing all activate the same neural pathways. Physical exercise, notably the exhale phase of heavy breathing during a run, strengthens the sympathetic-parasympathetic feedback loop. Over time, consistent activation of these pathways makes the nervous system more adaptive, making calm not just accessible — but the brain's default.")
                    ]
                ),

]

        // ════════════════════════════════════════════════════════════════
        // ANXIETY
        // ════════════════════════════════════════════════════════════════
        case .anxiety:
            return [

                EmotionArticle(
                    title: "The Amygdala's Alarm System",
                    subtitle: "How your brain detects and responds to danger.",
                    thumbnailName: "thumb_anxiety_amygdala",
                    readTime: "4 min read",
                    source: "Harvard Health",
                    sourceURL: "https://www.health.harvard.edu/staying-healthy/understanding-the-stress-response",
                    sections: [
                        ArticleSection(heading: "", body: "When the brain perceives a threat — whether a speeding car or a looming deadline — a precisely choreographed biological response unfolds within milliseconds. This response, evolved over millions of years to protect us from predators, is the foundation of what we experience as anxiety when it runs without an appropriate off-switch."),
                        ArticleSection(heading: "From Eyes to Alarm in Milliseconds", body: "The stress response begins when sensory information reaches the amygdala — an almond-shaped structure deep in the brain associated with emotional processing. The amygdala interprets the incoming signal and, if it detects danger, instantly sends a distress signal to the hypothalamus. This happens so rapidly that the response can be triggered before the brain's visual cortex has even finished processing what it saw. This is why you can jump away from a snake-like shape before consciously registering 'that might be a snake.'"),
                        ArticleSection(heading: "The Hypothalamus: Command Centre", body: "The hypothalamus functions like an emergency command centre. Upon receiving the amygdala's alarm, it activates the sympathetic nervous system — the 'gas pedal' — and sends signals through the autonomic nerves to the adrenal glands. These glands respond by releasing epinephrine (adrenaline) into the bloodstream. The result is immediate and comprehensive: heart rate surges, breathing quickens, pupils dilate, blood is redirected to muscles, extra glucose is released from storage, and senses sharpen. The body is primed to fight or flee."),
                        ArticleSection(heading: "The HPA Axis and Sustained Stress", body: "If the brain continues to perceive danger after the initial adrenaline surge fades, a second, slower system engages: the HPA axis — involving the hypothalamus, pituitary gland, and adrenal glands. The hypothalamus releases corticotropin-releasing hormone (CRH), triggering the pituitary to release ACTH, which causes the adrenal glands to secrete cortisol. Cortisol keeps the body on high alert, sustaining the stress state. When the perceived threat passes, cortisol levels should fall and the parasympathetic system restores calm. In anxiety disorders, this shutdown mechanism is impaired — the alarm stays on."),
                        ArticleSection(heading: "When the Alarm System Misfires", body: "Anxiety disorders occur when this otherwise adaptive system becomes dysregulated — firing responses that are disproportionate to actual threat. The amygdala becomes hyperreactive, interpreting neutral stimuli as dangerous. The prefrontal cortex, which normally provides rational oversight and can 'talk down' the amygdala, loses influence relative to the subcortical alarm systems. Individuals with anxiety disorders live in a state of physiological alert — perpetually braced for a threat that, to the rational mind, isn't there — but whose body and nervous system insist that it is.")
                    ]
                ),

                EmotionArticle(
                    title: "Anxiety's Hidden Toll on the Heart",
                    subtitle: "The cardiovascular consequences of chronic anxiety.",
                    thumbnailName: "thumb_anxiety_heart",
                    readTime: "4 min read",
                    source: "Harvard Health",
                    sourceURL: "https://www.health.harvard.edu/heart-health/calm-your-anxious-heart",
                    sections: [
                        ArticleSection(heading: "", body: "Anxiety is not confined to the mind. Its effects ripple outward into the cardiovascular system, the immune system, and the hormonal architecture of the entire body. Understanding the physical dimension of anxiety is essential — both for those who experience it and for anyone seeking to take meaningful care of their long-term health."),
                        ArticleSection(heading: "Anxiety and Depression: A Shared Biology", body: "Anxiety most often travels in the company of related conditions. As many as two-thirds of people with anxiety disorders also experience depression at some point in their lives, and over half of those with depression also carry an anxiety disorder. Long-term, unrelenting stress can serve as a precursor to both. This is not coincidental — anxiety and depression likely represent different expressions of a shared underlying neural biology, involving dysregulation of the same stress-response systems."),
                        ArticleSection(heading: "The Heart Under Threat", body: "People with generalised anxiety disorder experience statistically higher rates of heart attack and cardiac events. The effect is more pronounced in individuals who already carry a diagnosis of heart disease, and the risk rises with both the intensity and frequency of anxiety symptoms. Chronic anxiety changes the body's stress response in ways that directly harm the cardiovascular system: inappropriate blood pressure spikes, heart rhythm disturbances, and in severe cases, acute cardiac events triggered by intense psychological stress."),
                        ArticleSection(heading: "Inflammation, Platelets, and Plaque", body: "A malfunctioning stress response promotes systemic inflammation — a known driver of arterial damage. Inflammation injures the inner lining of blood vessels and sets the stage for coronary artery plaque build-up. Anxiety also depletes omega-3 fatty acids, and lower omega-3 levels are independently linked to higher cardiovascular risk. Research further shows that anxiety and depression make blood platelets 'stickier,' increasing the likelihood of blood clots — a key mechanism in heart attacks and strokes. These are not indirect or speculative links; they are well-documented biological pathways."),
                        ArticleSection(heading: "Treating Anxiety as Cardiac Care", body: "The connection between anxiety and heart health runs in both directions: cardiac diagnosis itself raises baseline anxiety, and that anxiety can worsen cardiac outcomes. This bidirectional relationship means that managing anxiety is not merely a mental health intervention — it is a meaningful component of cardiovascular care. Cognitive behavioural therapy, physical exercise, breathwork, adequate sleep, and appropriate medication all reduce physiological anxiety markers in ways that measurably benefit the heart as well as the mind.")
                    ]
                ),

]

        // ════════════════════════════════════════════════════════════════
        // SADNESS
        // ════════════════════════════════════════════════════════════════
        case .sadness:
            return [
                EmotionArticle(
                    title: "The Chemistry Behind Sadness",
                    subtitle: "Hormones, neurotransmitters, and the biology of low mood.",
                    thumbnailName: "sadness2",
                    readTime: "4 min read",
                    source: "The Insight Clinic",
                    sourceURL: "https://theinsightclinic.ca/the-chemistry-of-sadness-hormones/",
                    sections: [
                        ArticleSection(heading: "", body: "Although sadness is frequently seen as a purely emotional experience, it is also a biological process. The complex interplay between hormones and neurotransmitters in the human body plays a major role in regulating mood, and an understanding of these 'sadness molecules' reveals why low mood can sometimes feel beyond conscious control."),
                        ArticleSection(heading: "The Three Key Neurotransmitters", body: "Three neurotransmitters sit at the centre of sadness and depression. Dopamine — the brain's reward and motivation molecule — loses momentum when levels fall, draining pleasure from activities that once brought joy and reducing the drive to engage with the world. Norepinephrine governs alertness, attention, and the stress response; its imbalance produces persistent melancholy and heightened reactivity to negative events. Serotonin, often called the happiness neurotransmitter, contributes to emotional consistency and mood stability — low levels are strongly associated with the onset of depressive symptoms, and most antidepressants work precisely by increasing serotonin availability in the synapse."),
                        ArticleSection(heading: "What Disrupts the Balance", body: "The production and regulation of these neurotransmitters is influenced by multiple factors. Genetic predispositions can affect how neurotransmitters are produced and recycled. Environmental stressors — significant life events, chronic pressure, or trauma — can throw the delicate neurochemical balance into disarray. Neurological factors, including structural differences in mood-regulating brain regions, also play a role. Perhaps importantly, the relationship runs in both directions: low mood changes neurochemistry, and neurochemistry shapes mood, creating feedback loops that can become self-sustaining."),
                        ArticleSection(heading: "Cortisol's Role in Emotional Weight", body: "Cortisol, the body's primary stress hormone, plays an important secondary role in sadness. During periods of grief or prolonged sadness, cortisol can remain elevated, impairing hippocampal function (affecting memory), disrupting sleep architecture, and increasing systemic inflammation. This explains why profound sadness can feel physically heavy — it genuinely is a physiological state, not just a metaphor. Sleep deprivation compounds the effect, further suppressing serotonin and dopamine production, creating conditions in which the brain becomes increasingly unable to lift its own mood."),
                        ArticleSection(heading: "Moving Toward Balance", body: "The neurochemistry of sadness is not destiny. Aerobic exercise has been shown to raise dopamine and serotonin levels acutely and to stimulate neuroplasticity, helping the brain rewire its mood regulation circuitry. Social connection increases oxytocin, which buffers the cortisol response. Adequate sleep is essential for neurotransmitter replenishment. For profound or persistent imbalances, medications such as SSRIs can restore serotonin availability while other therapeutic and lifestyle interventions address the underlying causes. Understanding the biology of sadness removes shame from the experience — it is a state of chemistry as much as circumstance.")
                    ]
                ),

                EmotionArticle(
                    title: "Why Sadness Serves a Purpose",
                    subtitle: "The evolutionary and psychological value of feeling low.",
                    thumbnailName: "sadness3",
                    readTime: "4 min read",
                    source: "Berkeley Wellbeing Institute",
                    sourceURL: "https://www.berkeleywellbeing.com/sadness.html",
                    sections: [
                        ArticleSection(heading: "", body: "In a culture that prizes positivity and productivity, sadness is often treated as a problem to be fixed. But evolutionary biology and clinical psychology offer a more nuanced picture — one in which sadness is not a malfunction but a sophisticated adaptive response that serves essential psychological and social functions."),
                        ArticleSection(heading: "Sadness as an Emotional Signal", body: "Sadness communicates something important: that a loss has occurred, that something meaningful has changed, or that a need is going unmet. It is the brain's way of flagging that attention and resources should be redirected — toward self-reflection, toward mourning, toward reconnection with what matters. This signalling function has clear survival value. It slows us down when we need to process rather than act, and it conserves energy during periods of genuine scarcity or loss."),
                        ArticleSection(heading: "Sadness Deepens Empathy", body: "Experiencing sadness makes us more attuned to the suffering of others. The neural pathways activated during personal sadness overlap significantly with those engaged in empathy — including the anterior cingulate cortex and the insula. This overlap is not coincidental. The capacity to feel sad is part of what makes us capable of genuine compassion. Research consistently shows that individuals who allow themselves to feel and process their own sadness score higher on measures of empathic accuracy — the ability to correctly perceive what others are feeling."),
                        ArticleSection(heading: "The Cost of Suppression", body: "Attempts to suppress or bypass sadness have measurable psychological costs. Emotional suppression — the deliberate effort not to feel or express an emotion — requires cognitive effort and has been linked to higher baseline cortisol, reduced immune function, and paradoxically, more intrusive emotional thoughts. The concept of 'toxic positivity' describes the cultural and interpersonal pressure to maintain a positive front, which research shows is associated with greater loneliness, because it prevents honest emotional sharing and authentic connection."),
                        ArticleSection(heading: "Allowing Space for Sadness", body: "The most effective approach to sadness is neither to wallow in it nor to suppress it, but to acknowledge it and create the conditions for it to move through. Naming the emotion explicitly — a practice supported by affective neuroscience research — reduces activity in the amygdala and increases prefrontal cortex involvement, shifting the brain from reactive to reflective mode. Talking to someone trusted, journalling, physical movement, and time in nature all support the natural processing arc of sadness. Sadness, when honoured rather than avoided, is often one of the most direct paths to genuine emotional integration and growth.")
                    ]
                )
            ]

        // ════════════════════════════════════════════════════════════════
        // LOVE
        // ════════════════════════════════════════════════════════════════
        case .love:
            return [

                EmotionArticle(
                    title: "Love's Chemical Cocktail",
                    subtitle: "Dopamine, oxytocin, and serotonin — the molecules of connection.",
                    thumbnailName: "love1",
                    readTime: "4 min read",
                    source: "Pacific Neuroscience Institute",
                    sourceURL: "https://www.pacificneuroscienceinstitute.org/blog/brain-health/the-neuroscience-of-love-and-connection/",
                    sections: [
                        ArticleSection(heading: "", body: "Love and connection are often described as mysterious forces — felt deeply but difficult to explain. Modern neuroscience has begun to demystify their inner workings, revealing that what we experience as love is, at its biological core, an orchestrated release of specific neurotransmitters and hormones that shape how we think, feel, and behave toward others."),
                        ArticleSection(heading: "Dopamine: The Euphoria Molecule", body: "Dopamine is the brain's reward and motivation neurotransmitter, and it plays a central role in the experience of romantic love. When we fall for someone, dopamine levels surge through the brain's mesolimbic pathway, producing a euphoria that neurologically resembles the effects of addictive substances. This explains the obsessive, energising quality of early love — the inability to stop thinking about the person, the heightened energy, the sense that the world has been reorganised around a single individual. Every message, glance, and shared moment becomes a potential reward, keeping the brain in a state of perpetual anticipation."),
                        ArticleSection(heading: "Oxytocin: The Bonding Hormone", body: "Known as the 'bonding hormone,' oxytocin is released during physical touch, intimacy, eye contact, and meaningful social interaction. It strengthens emotional bonds and builds trust between partners, family members, and close friends. In the early stages of love, oxytocin works alongside dopamine to reinforce the connection. Over time — as romantic intensity gives way to deeper attachment — oxytocin and vasopressin become increasingly dominant, sustaining the sense of safety, loyalty, and long-term commitment that characterises enduring relationships."),
                        ArticleSection(heading: "Serotonin and the Obsessive Mind", body: "Serotonin, which helps regulate mood and emotional stability, behaves unexpectedly in early love. Research has shown that serotonin levels in newly-in-love individuals resemble those found in people with obsessive-compulsive disorder — an intriguing finding that may explain why early infatuation feels all-consuming and intrusive. Thoughts of the beloved arise unbidden; the mind returns compulsively to memories and possibilities. As the relationship matures and serotonin stabilises, this obsessive intensity softens into something steadier and more sustainable."),
                        ArticleSection(heading: "From Passion to Deep Attachment", body: "The neurochemical landscape of love shifts significantly over time. Early-stage love is dominated by dopamine and norepinephrine — generating excitement, energy, and focus. Long-term attachment sees oxytocin and vasopressin take precedence, producing a state of emotional security and deep trust that is, in many ways, more nourishing than the initial rush. This is not love diminishing; it is love maturing. The brain adapts its chemistry to sustain connection across years, not just months, replacing intensity with stability — arguably the more impressive feat.")
                    ]
                ),

                EmotionArticle(
                    title: "How Love Reshapes the Brain",
                    subtitle: "The brain regions that activate — and quiet — when we love.",
                    thumbnailName: "love2",
                    readTime: "4 min read",
                    source: "Pacific Neuroscience Institute",
                    sourceURL: "https://www.pacificneuroscienceinstitute.org/blog/brain-health/the-neuroscience-of-love-and-connection/",
                    sections: [
                        ArticleSection(heading: "", body: "Love is not a single emotion processed in a single brain region. It is a dynamic, distributed experience — activating reward circuits, quieting fear responses, modulating rational thought, and, when it ends, triggering some of the same neural pathways that process physical pain. Understanding where love lives in the brain illuminates why it feels the way it does."),
                        ArticleSection(heading: "The Ventral Tegmental Area: Love's Engine", body: "The ventral tegmental area (VTA) is the brain's primary dopamine production hub and is heavily activated during romantic attraction. It sits at the centre of the mesolimbic reward pathway — the same circuit involved in natural rewards like food and water. When someone falls in love, the VTA fires intensely, sending dopamine-rich signals to regions including the nucleus accumbens and the prefrontal cortex. This is why love motivates with such urgency: the brain has classified the beloved as a primary reward, comparable in motivational weight to survival needs."),
                        ArticleSection(heading: "The Amygdala Quiets Down", body: "Perhaps the most surprising finding of love neuroscience is what decreases. The amygdala — typically the brain's alarm system, vigilantly scanning for threats — shows reduced activity when people are in love or deeply connected. This deactivation likely explains the sense of emotional safety and reduced anxiety that accompanies genuine connection. In the presence of a trusted partner, the nervous system interprets the social environment as safe, allowing defences to lower. This is neurologically measurable — love, literally, calms the brain's threat detector."),
                        ArticleSection(heading: "Prefrontal Cortex and the Idealism of Early Love", body: "The prefrontal cortex, responsible for rational thought, critical evaluation, and impulse control, shows reduced activity in the early stages of passionate love. This may contribute to the well-documented idealisation of early romance — the tendency to perceive a new partner as near-perfect, to overlook inconsistencies, and to make impulsive commitments. As the relationship deepens and the neurochemical storm of early love stabilises, prefrontal activity returns, enabling more balanced assessment and mature negotiation of the relationship."),
                        ArticleSection(heading: "Heartbreak and the Pain Network", body: "Just as love activates reward circuits, heartbreak and social loss trigger neural responses associated with physical pain. Brain imaging studies show that romantic rejection activates the anterior cingulate cortex and the insula — regions that process physical pain signals. This is not metaphorical. The same neural substrates that register a broken bone or a burned finger respond to emotional rejection. This overlap likely evolved to prevent social exclusion, which in ancestral environments was genuinely life-threatening. It is also why, after a breakup, the grief feels viscerally physical.")
                    ]
                ),
            ]

        // ════════════════════════════════════════════════════════════════
        // HAPPY
        // ════════════════════════════════════════════════════════════════
        case .happy:
            return [

                EmotionArticle(
                    title: "The Seven Neurochemicals of Joy",
                    subtitle: "Meet the brain molecules that generate happiness.",
                    thumbnailName: "happy1",
                    readTime: "4 min read",
                    source: "Psychology Today",
                    sourceURL: "https://www.psychologytoday.com/us/blog/the-athletes-way/201211/the-neurochemicals-of-happiness",
                    sections: [
                        ArticleSection(heading: "", body: "Happiness is not a single feeling stored in one brain region — it is an orchestra of neurochemicals, each playing a distinct role in shaping the subjective experience of feeling good. Understanding these molecules is not merely academic: it reveals practical ways to support the brain states underlying genuine wellbeing."),
                        ArticleSection(heading: "Dopamine: The Reward Molecule", body: "Dopamine is the brain's achievement molecule. Every type of reward-seeking behaviour studied increases dopamine transmission. It surges with the anticipation of reward, spikes at attainment, and drives further goal-directed behaviour. This is why setting and achieving goals — even small ones — reliably improves mood. Interestingly, people with more extraverted, uninhibited personality profiles tend to have naturally higher baseline dopamine levels, suggesting that neurochemistry shapes temperament as much as the reverse."),
                        ArticleSection(heading: "Oxytocin: The Bonding Molecule", body: "Oxytocin is directly linked to human bonding, trust, and social warmth. High levels of oxytocin have been correlated with romantic attachment, and skin-to-skin contact, affection, and intimacy are among the most potent triggers for its release. In a world increasingly mediated by screens, maintaining face-to-face connection is not merely socially meaningful — it is neurochemically essential. A 2003 study showed oxytocin rose in both dogs and their owners after cuddling, suggesting that the bonding function of the molecule extends even across species."),
                        ArticleSection(heading: "Endorphins and Endocannabinoids", body: "Endorphins are the body's natural painkillers — released during physical exertion, laughter, and excitement. Long attributed to the 'runner's high,' more recent research from the University of Arizona suggests that endocannabinoids — internally produced compounds that activate the same receptors as cannabis — are actually the primary drivers of exercise-induced euphoria. Anandamide, derived from the Sanskrit word for 'bliss,' is the most well-known endocannabinoid and appears to be responsible for the sense of floating peace that follows sustained aerobic exercise."),
                        ArticleSection(heading: "Serotonin and Emotional Baseline", body: "Serotonin contributes to emotional stability, social belonging, and a general sense of being grounded and well. Its influence is more about maintaining a positive baseline than generating peaks of pleasure. Low serotonin is associated with irritability, vulnerability to depression, and difficulty tolerating frustration. Sunlight exposure, aerobic exercise, social connection, and a diet rich in tryptophan (its precursor) all support serotonin production. Spending time in natural light for 20–30 minutes each morning is among the most cost-effective serotonin regulators available."),
                        ArticleSection(heading: "Cultivating a Neurochemically Rich Life", body: "The insight from neurochemistry is that happiness is not an accident — it is the by-product of a life rich in activities that support these molecular systems: movement, connection, purposeful achievement, physical affection, creative challenge, and time in nature. No single source can sustain all of them. The brain requires variety, novelty, and genuine engagement across multiple domains. A life built to produce regular, varied neurochemical reward is not a life of hedonism — it is a life of genuine flourishing.")
                    ]
                ),
                EmotionArticle(
                    title: "A Smile Rewires the Brain",
                    subtitle: "The neuroscience behind expression and emotional feedback.",
                    thumbnailName: "happy3",
                    readTime: "4 min read",
                    source: "NBC News",
                    sourceURL: "https://www.nbcnews.com/better/health/smiling-can-trick-your-brain-happiness-boost-your-health-ncna822591",
                    sections: [
                        ArticleSection(heading: "", body: "The relationship between facial expression and emotional experience is bidirectional. We smile because we are happy — but we also, to a measurable degree, become happier because we smile. This counter-intuitive finding, supported by decades of research, reveals just how deeply the body and mind are intertwined."),
                        ArticleSection(heading: "The Facial Feedback Hypothesis", body: "The facial feedback hypothesis proposes that facial muscle activity sends signals back to the brain that influence emotional processing. When the muscles used in smiling contract — even without genuine joy, even with a pencil held between the teeth as in early experiments — the brain interprets the motor signal as evidence of positive affect and adjusts its emotional processing accordingly. It doesn't verify authenticity. The brain, in a sense, trusts the face."),
                        ArticleSection(heading: "Smiling Under Stress", body: "Researchers at the University of Kansas published compelling findings: people instructed to smile — including with forced, deliberate smiles — showed measurably lower heart rates and faster recovery from stressful tasks compared to neutral-expression controls. Smiling changes the physiological stress response, not merely the subjective experience of it. Related research links smiling to lower resting blood pressure and, in longitudinal studies, to greater longevity — a finding that held even when controlling for initial wellbeing levels."),
                        ArticleSection(heading: "Immunity and the Happy Brain", body: "The study of psychoneuroimmunology — the science of how psychological states influence the immune system — repeatedly confirms that positive emotional states strengthen the body's resistance to illness, while negative states (including depression) suppress it. Dr. Murray Grossan notes that 'just the physical act of smiling can make a difference in building your immunity' — because the brain, reading the facial expression, adjusts its neurochemical output accordingly, including signals that reach the immune system."),
                        ArticleSection(heading: "Smiling as a Daily Practice", body: "From a practical standpoint, this research suggests that smiling can function as a brief, low-cost mood regulation tool — particularly in moments when emotional inertia makes genuine positive emotion hard to access. Success coaches and mindfulness practitioners have long advised deliberate smiling as a rapid mood reset. The mechanism is straightforward: the expression activates the same neural and hormonal pathways that genuine happiness would activate, gently nudging the internal state toward what the face is signalling.")
                    ]
                )
            ]

        // ════════════════════════════════════════════════════════════════
        // ANGRY
        // ════════════════════════════════════════════════════════════════
        case .angry:
            return [

                EmotionArticle(
                    title: "What Happens in Your Brain When You're Angry",
                    subtitle: "The neural circuits that drive rage — and regulate it.",
                    thumbnailName: "angry1",
                    readTime: "4 min read",
                    source: "Verywell Mind",
                    sourceURL: "https://www.verywellmind.com/what-happens-in-your-brain-when-youre-angry-8753372",
                    sections: [
                        ArticleSection(heading: "", body: "Anger is one of the most powerful and immediate human emotions — felt in the body as much as the mind, with the racing heart, flushed skin, and tensed muscles that signal the brain has shifted into a state of high alert. Understanding the neural architecture of anger is the first step toward working with it more skillfully."),
                        ArticleSection(heading: "The Amygdala Fires an Alarm", body: "When a perceived threat or injustice is detected, the amygdala — the brain's primary emotional alarm — activates immediately. It processes the emotional significance of incoming stimuli at a speed that bypasses conscious awareness, triggering the fight-or-flight response before the prefrontal cortex has had a chance to evaluate the situation rationally. Adrenaline and norepinephrine flood the body. Heart rate surges. Blood pressure rises. The face reddens as blood rushes to the muscles. The body is primed to confront the perceived threat."),
                        ArticleSection(heading: "The Prefrontal Cortex: Anger's Regulator", body: "The prefrontal cortex (PFC) — the brain's rational executive — normally provides top-down regulation of the amygdala's emotional responses. In healthy individuals, the PFC's involvement suppresses impulsive angry behaviour and re-routes the emotional energy toward measured, constructive response. This is not suppression in the psychological sense — it is governance. The PFC examines the amygdala's alarm, assesses the context, and determines an appropriate response. Anger management, at its neurological core, is the practice of keeping the PFC involved when the amygdala wants to take over entirely."),
                        ArticleSection(heading: "When Regulation Fails", body: "In individuals with dysregulated anger — whether due to depression, trauma, or chronic stress — the PFC's regulatory influence over the amygdala weakens. Harvard-affiliated research using PET imaging found that in people with depression who experience anger attacks, the orbital frontal cortex (part of the PFC) does not activate during angry moments. Without this neurological brake, amygdala activity intensifies and outbursts occur that are disproportionate to the triggering event and out of character for the individual."),
                        ArticleSection(heading: "Healthy Anger vs. Destructive Anger", body: "Anger is not inherently destructive. The American Psychological Association defines anger as a response to perceiving that someone has deliberately wronged you — and as an evolved emotion, it developed specifically to motivate defence against genuine injustice. Appropriate anger expression — communicating clearly, setting firm boundaries, advocating for fair treatment — carries mental and physical health benefits. The risks arise from two dysfunctional extremes: suppression (which elevates cardiovascular risk and depressive symptoms) and explosive expression (which damages relationships and can literally injure developing brains that witness it).")
                    ]
                ),

                EmotionArticle(
                    title: "Anger Management: Inside the Brain",
                    subtitle: "What Harvard neuroscience reveals about wrath's neural roots.",
                    thumbnailName: "angry2",
                    readTime: "4 min read",
                    source: "Harvard Medicine Magazine",
                    sourceURL: "https://magazine.hms.harvard.edu/articles/anger-management",
                    sections: [
                        ArticleSection(heading: "", body: "Flares and flashes. Outbursts and eruptions. The language used to describe anger tends to be volcanic — and science may explain exactly why. Research from Harvard-affiliated institutions has been unpacking the neural mechanisms of anger for decades, revealing a system that is both more complex and more treatable than previously understood."),
                        ArticleSection(heading: "PET Imaging and the Angry Brain", body: "Dr. Darin Dougherty at Massachusetts General Hospital used positron emission tomography (PET) imaging to examine which brain regions activate during anger in healthy individuals with no history of depression or anger episodes. Subjects recalled their most intensely angry autobiographical memories — a methodology that produces more robust emotional activation than passively viewing upsetting images. During these recalls, two regions lit up: the amygdala (as expected) and part of the orbital frontal cortex, just above the eyes, which simultaneously fired as a neurological brake on the emotion. Healthy people feel anger — but they can suppress it before acting on it."),
                        ArticleSection(heading: "When the Brake Fails", body: "In people with major depressive disorder who experience inappropriate anger attacks, Dougherty found a striking difference: during angry moments, the orbital frontal cortex did not activate. The brake failed to engage. Amygdala activity increased unchecked, and outbursts ensued — disproportionate to the triggering situation, and often described afterward as alien to the person's own character. Understanding this mechanism explains the link between depression and anger attacks, and suggests that treatments targeting either the depression or the PFC pathway may resolve both."),
                        ArticleSection(heading: "Verbal Anger and the Developing Brain", body: "Research by Dr. Martin Teicher at McLean Hospital found that verbal anger — specifically parental and peer verbal abuse — causes structural brain changes measurable by diffusion-tensor MRI, equivalent in magnitude to those seen in victims of physical abuse. Three neural pathways were disrupted: the arcuate fasciculus (involved in language processing), part of the cingulum bundle (linked to PTSD, depression, and dissociation), and part of the fornix (associated with anxiety). The expression of intense, unregulated anger toward children does not merely cause emotional distress — it alters the physical structure of the brain."),
                        ArticleSection(heading: "Anger as a Treatable Condition", body: "Dougherty's ongoing research applies these neuroimaging techniques to track what happens in the brain during treatment for anger using cognitive behavioural therapy and pharmacotherapy — documenting how these interventions alter the activation patterns of the amygdala and orbital frontal cortex. The emerging picture is that anger, far from being a character flaw or a permanent personality trait, is a neurologically rooted condition that responds to the same range of scientific interventions as depression or anxiety. Understanding this reframes both the experience of anger and the means of working with it.")
                    ]
                ),
            ]
        }
    }
}
